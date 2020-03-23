set templateFile="C:\Users\jogoldbe\git\automation-api-community-solutions\1-general-examples\use-case-azure-predictive-maintenance\ARM_Resources\azuredeploy.json"
set parameterfile="C:\Users\jogoldbe\git\automation-api-community-solutions\1-general-examples\use-case-azure-predictive-maintenance\ARM_Resources\azuredeploy.parameters.json"

az deployment group create --debug --name iotusecase --resource-group jogoldbe_TutorialRG --template-file %templateFile% --parameters %ParameterFile%