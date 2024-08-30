--put the contents of this file in your miz as a script to run at startup. this is required to load the config, and allow for multiple externally loaded configs to co-exist on a server environment, for different miz's.
--this also will set the save data names so reboots work fine, and wont conflict with other ops/missions ongoing.

MissionName = %MissionName% --choose your name of choice, and set the config name to match.


--FilePath = the position on disk for your 'scripts' folder containing everything. This should be defined by ChaosScriptLoader as a dependancy. If you are not using ChaosScriptLoader, you will need to create define this too.
