{ config, pkgs, ... }: 

{
	home.username = "dmitry";
	home.homeDirectory = "/home/dmitry";

	programs = {
		git = {
			enable = true;
			userName = "dmitry.batalov";
			userEmail = "dmtiryabat@gmail.com";
			extraConfig = {
				init.defaultBranch = "main";
			};
		};
		lazygit.enable = true;
	};

	home.stateVersion = "25.05";
	programs.bash = {
		enable = true;
		shellAliases = {
			btw = "echo i use nisos, btw";
		};
	};
	

	# home.file.".config/i3".source = ./config/i3;
}
