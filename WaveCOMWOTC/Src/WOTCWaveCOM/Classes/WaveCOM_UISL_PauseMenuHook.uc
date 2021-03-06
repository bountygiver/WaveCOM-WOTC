class WaveCOM_UISL_PauseMenuHook extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local WaveCOM_MissionLogic_WaveCOM MissionLogic;
	local WaveCOM_UILoadoutButton lo;

	if (UIPauseMenu(Screen) != none)
	{
		MissionLogic = WaveCOM_MissionLogic_WaveCOM(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'WaveCOM_MissionLogic_WaveCOM'));
		//`log("Pause menu detected",, 'PauseTransferHook');
		if (MissionLogic != none)
		{
			//`log("Mission Logic detected",, 'PauseTransferHook');
			if (MissionLogic.WaveStatus == eWaveStatus_Preparation)
			{
				//`log("Transfer button created",, 'PauseTransferHook');
				Screen.Spawn(class'UIButton', Screen).InitButton('btnTransferMission', "Transfer to new map", TransferMission).AnchorTopRight().SetPosition(0 - 300, 20);
			}
		}
	}
	else if (UITacticalHUD(Screen) != none)
	{
		lo = Screen.Spawn(class'WaveCOM_UILoadoutButton', Screen);
		lo.InitScreen(Screen);
	}
	else if (UIFinalShell(Screen) != none)
	{
		Screen.Spawn(class'WaveCOMFinalShellPatcher', Screen).InitPanel('WaveCOMShellPatcher');
	}
}

simulated function TransferMission(UIButton ButtonClicked)
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Alert;
	DialogData.bMuteAcceptSound = true;
	DialogData.strTitle = "Confirm transfer mission";
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	DialogData.strText = "Do you want to transfer all units to a new map? This can fix performance issues and generate a new undestroyed map.\nNote that if you have more units than the spawn point can handle, you need to deploy the extra soldiers manually after freeing up the initial space.";
	DialogData.fnCallback = ComfirmMissionTransfer;
	`PRES.UIRaiseDialog(DialogData);
}


simulated function ComfirmMissionTransfer(name Action)
{
	if(Action == 'eUIAction_Accept')
	{
		class'X2DownloadableContentInfo_WOTCWaveCOM'.static.StaticWaveCOMMissionTransfer();
	}
}