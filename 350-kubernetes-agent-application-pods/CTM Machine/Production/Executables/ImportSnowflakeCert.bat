"C:\Program Files\BMC Software\Control-M Agent\Default\CM\JRE\bin\keytool" -import -alias snowflake -keystore "C:\Program Files\BMC Software\Control-M Agent\Default\CM\AP\data\security\apcerts" -storepass appass -file C:\bmc_stuff\snow.cer

"C:\Program Files\BMC Software\Control-M Agent\Default\CM\JRE\bin\keytool" -list -v -keystore "C:\Program Files\BMC Software\Control-M Agent\Default\CM\AP\data\security\apcerts"
