class WaveCOM_UIArmory_WeaponUpgrade extends UIArmory_WeaponUpgrade;

simulated function InitArmory(StateObjectReference UnitOrWeaponRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	super(UIArmory).InitArmory(UnitOrWeaponRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	`HQPRES.CAMLookAtNamedLocation( CameraTag, 0 );

	FontSize = bIsIn3D ? class'UIUtilities_Text'.const.BODY_FONT_SIZE_3D : class'UIUtilities_Text'.const.BODY_FONT_SIZE_2D;
	
	SlotsListContainer = Spawn(class'UIPanel', self);
	SlotsListContainer.bAnimateOnInit = false;
	SlotsListContainer.InitPanel('leftPanel');
	SlotsList = class'UIArmory_Loadout'.static.CreateList(SlotsListContainer);
	SlotsList.OnChildMouseEventDelegate = OnListChildMouseEvent;
	SlotsList.OnSelectionChanged = PreviewUpgrade;
	SlotsList.OnItemClicked = OnItemClicked;
	SlotsList.Navigator.LoopSelection = false;	
	//INS: - JTA 2016/3/2
	SlotsList.bLoopSelection = false;
	SlotsList.Navigator.LoopOnReceiveFocus = true;
	//INS: WEAPON_UPGRADE_UI_FIXES, BET, 2016-03-23
	SlotsList.bCascadeFocus = true;
	SlotsList.bPermitNavigatorToDefocus = true;

	CustomizeList = Spawn(class'UIList', SlotsListContainer);
	CustomizeList.ItemPadding = 5;
	CustomizeList.bStickyHighlight = false;
	CustomizeList.InitList('customizeListMC');
	CustomizeList.AddOnInitDelegate(UpdateCustomization);
	CustomizeList.Navigator.LoopSelection = false;
	CustomizeList.bLoopSelection = false;
	CustomizeList.Navigator.LoopOnReceiveFocus = true;
	CustomizeList.bCascadeFocus = true;
	CustomizeList.bPermitNavigatorToDefocus = true;

	UpgradesListContainer = Spawn(class'UIPanel', self);
	UpgradesListContainer.bAnimateOnInit = false;
	UpgradesListContainer.InitPanel('rightPanel');
	UpgradesList = class'UIArmory_Loadout'.static.CreateList(UpgradesListContainer);
	UpgradesList.OnChildMouseEventDelegate = OnListChildMouseEvent;
	UpgradesList.OnSelectionChanged = PreviewUpgrade;
	UpgradesList.OnItemClicked = OnItemClicked;

	Navigator.RemoveControl(UpgradesList);

	WeaponStats = Spawn(class'UIArmory_WeaponUpgradeStats', self).InitStats('weaponStatsMC', WeaponRef);
	WeaponStats.DisableNavigation(); 

	if(GetUnit() != none)
		WeaponRef = GetUnit().GetItemInSlot(eInvSlot_PrimaryWeapon).GetReference();
	else
		WeaponRef = UnitOrWeaponRef;

	SetWeaponReference(WeaponRef);

	`XCOMGRI.DoRemoteEvent(EnableWeaponLightingEvent);

	PreviewUpgrade(SlotsList, 0); //Force a refresh of the weapon pawn
}

simulated function PreviewUpgrade(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Item Weapon;
	local XComGameState ChangeState;
	local X2WeaponUpgradeTemplate UpgradeTemplate;
	local int SlotIndex;

	if(ItemIndex == INDEX_NONE)
	{
		SetUpgradeText();
		return;
	}

	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Weapon_Attachement_Upgrade");
	ChangeState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Visualize Weapon Upgrade");

	Weapon = XComGameState_Item(ChangeState.ModifyStateObject(class'XComGameState_Item', WeaponRef.ObjectID));

	UpgradeTemplate = UIArmory_WeaponUpgradeItem(ContainerList.GetItem(ItemIndex)).UpgradeTemplate;
	SlotIndex = UIArmory_WeaponUpgradeItem(SlotsList.GetSelectedItem()).SlotIndex;

	Weapon.DeleteWeaponUpgradeTemplate(SlotIndex);
	if (UpgradeTemplate != none)
	{
		Weapon.ApplyWeaponUpgradeTemplate(UpgradeTemplate, SlotIndex);

		SetUpgradeText(UpgradeTemplate.GetItemFriendlyName(), UpgradeTemplate.GetItemBriefSummary());

		WeaponStats.PopulateData(Weapon, UpgradeTemplate);
	}

	`XCOMHISTORY.CleanupPendingGameState(ChangeState);
}

simulated function SetWeaponReference(StateObjectReference NewWeaponRef)
{
	local XComGameState_Item Weapon;

	if(CustomizationState != none)
		SubmitCustomizationChanges();

	WeaponRef = NewWeaponRef;
	Weapon = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(WeaponRef.ObjectID));

	SetWeaponName(Weapon.GetMyTemplate().GetItemFriendlyName());

	ChangeActiveList(SlotsList, true);
	UpdateOwnerSoldier();
	UpdateSlots();

	if(CustomizeList.bIsInited)
		UpdateCustomization(none);

	MC.FunctionVoid("animateIn");
}

simulated function ChangeActiveList(UIList kActiveList, optional bool bSkipAnimation)
{
	local XComGameState_Item WeaponItemState;
	local UIArmory_WeaponUpgradeItem SelectedItem;

	ActiveList = kActiveList;
	SelectedItem = UIArmory_WeaponUpgradeItem(SlotsList.GetSelectedItem());
	if (SelectedItem != none)
		SelectedItem.SetLocked(ActiveList != SlotsList);
	ActiveList.SetSelectedIndex(0); //bsg-jneal (7.12.16): Let the start index be 0 for console so the list has an initial selection on opening, having the list init at index -1 is more of a mouse/keyboard style
	
	if(ActiveList == SlotsList)
	{
		if(!bSkipAnimation)
			MC.FunctionVoid("closeList");

		// disable list item selection on LockerList, enable it on EquippedList
		UpgradesListContainer.DisableMouseHit();
		SlotsListContainer.EnableMouseHit();

		//Reset the weapon location tag as it may have changed if we were looking at attachments
		WeaponItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(WeaponRef.ObjectID));

		WeaponStats.PopulateData(WeaponItemState);

		SetUpgradeText();
		SlotsListContainer.EnableNavigation();
		UpgradesListContainer.DisableNavigation();
		Navigator.SetSelected(SlotsListContainer);

		if(SlotsListContainer.Navigator.SelectedIndex == -1)
			SlotsListContainer.Navigator.SetSelected(SlotsList);

		if(SlotsList.SelectedIndex == -1)
			SlotsList.SetSelectedIndex(0);
		else
			PreviewUpgrade(SlotsList, SlotsList.SelectedIndex); //Reset weapon pawn so it can be rotated
	}
	else
	{
		if(!bSkipAnimation)
			MC.FunctionVoid("openList");
		
		// disable list item selection on LockerList, enable it on EquippedList
		UpgradesListContainer.EnableMouseHit();
		SlotsListContainer.DisableMouseHit();
		SlotsListContainer.DisableNavigation();
		UpgradesListContainer.EnableNavigation();
		Navigator.SetSelected(UpgradesListContainer);
		UpgradesListContainer.Navigator.SetSelected(UpgradesList);
	}

	UpdateNavHelp();
}

// Only allowed to customize name, please use customization menu for everything else
simulated function UpdateCustomization(UIPanel DummyParam)
{
	local int i;
	local XGParamTag LocTag;

	CreateCustomizationState();

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Caps(UpdatedWeapon.GetMyTemplate().GetItemFriendlyName(UpdatedWeapon.ObjectID));

	SetCustomizeTitle(`XEXPAND.ExpandString(m_strCustomizeWeaponTitle));

	// WEAPON NAME
	//-----------------------------------------------------------------------------------------

	GetCustomizeItem(i++).UpdateDataDescription(m_strCustomizeWeaponName, OpenWeaponNameInputBox);

	CustomizeList.SetPosition(CustomizationListX, CustomizationListY - CustomizeList.ShrinkToFit() - CustomizationListYPadding);

	CleanupCustomizationState();
}
simulated function PrevSoldier()
{
	// Do not switch soldiers in this screen
}

simulated function NextSoldier()
{
	// Do not switch soldiers in this screen
}
