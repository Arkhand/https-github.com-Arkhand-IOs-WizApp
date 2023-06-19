//
// wizapp
//
// Created by SAP BTP SDK Assistant for iOS v9.1.3 application on 16/06/23
//

import ESPMContainerFmwk
import Foundation
import SAPCommon
import SAPFiori
import SAPFoundation
import SAPOData

class SalesOrderItemDetailViewController: FUIFormTableViewController, SAPFioriLoadingIndicator {
    var dataService: ESPMContainer!
    private var validity = [String: Bool]()
    var allowsEditableCells = false

    private var _entity: ESPMContainerFmwk.SalesOrderItem?
    var entity: ESPMContainerFmwk.SalesOrderItem {
        get {
            if _entity == nil {
                _entity = createEntityWithDefaultValues()
            }
            return _entity!
        }
        set {
            _entity = newValue
        }
    }

    private let logger = Logger.shared(named: "SalesOrderItemMasterViewControllerLogger")
    var loadingIndicator: FUILoadingIndicatorView?
    var entityUpdater: ESPMContainerEntityUpdaterDelegate?
    var tableUpdater: ESPMContainerEntitySetUpdaterDelegate?
    private let okTitle = NSLocalizedString("keyOkButtonTitle",
                                            value: "OK",
                                            comment: "XBUT: Title of OK button.")
    var preventNavigationLoop = false
    var entitySetName: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(FUIDatePickerFormCell.self, forCellReuseIdentifier: FUIDatePickerFormCell.reuseIdentifier)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "updateEntity" {
            // Show the Detail view with the current entity, where the properties scan be edited and updated
            logger.info("Showing a view to update the selected entity.")
            let dest = segue.destination as! UINavigationController
            let detailViewController = dest.viewControllers[0] as! SalesOrderItemDetailViewController
            detailViewController.title = NSLocalizedString("keyUpdateEntityTitle", value: "Update Entity", comment: "XTIT: Title of update selected entity screen.")
            detailViewController.dataService = dataService
            detailViewController.entity = entity
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: detailViewController, action: #selector(detailViewController.updateEntity))
            detailViewController.navigationItem.rightBarButtonItem = doneButton
            let cancelButton = UIBarButtonItem(title: NSLocalizedString("keyCancelButtonToGoPreviousScreen", value: "Cancel", comment: "XBUT: Title of Cancel button."), style: .plain, target: detailViewController, action: #selector(detailViewController.cancel))
            detailViewController.navigationItem.leftBarButtonItem = cancelButton
            detailViewController.allowsEditableCells = true
            detailViewController.entityUpdater = self
            detailViewController.tableUpdater = tableUpdater
            detailViewController.entitySetName = entitySetName
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return cellForCurrencyCode(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.currencyCode)
        case 1:
            return cellForDeliveryDate(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.deliveryDate)
        case 2:
            return cellForGrossAmount(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.grossAmount)
        case 3:
            return cellForItemNumber(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.itemNumber)
        case 4:
            return cellForNetAmount(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.netAmount)
        case 5:
            return cellForProductID(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.productID)
        case 6:
            return cellForQuantity(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.quantity)
        case 7:
            return cellForQuantityUnit(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.quantityUnit)
        case 8:
            return cellForSalesOrderID(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.salesOrderID)
        case 9:
            return cellForTaxAmount(tableView: tableView, indexPath: indexPath, currentEntity: entity, property: SalesOrderItem.taxAmount)
        case 10:
            let cell = CellCreationHelper.cellForDefault(tableView: tableView, indexPath: indexPath, editingIsAllowed: false)
            cell.keyName = "Header"
            if entity.isNew {
                cell.title.textColor = UIColor.preferredFioriColor(forStyle: .primaryLabel)
            }
            cell.value = " "
            cell.accessoryType = .disclosureIndicator
            return cell

        case 11:
            let cell = CellCreationHelper.cellForDefault(tableView: tableView, indexPath: indexPath, editingIsAllowed: false)
            cell.keyName = "ProductDetails"
            if entity.isNew {
                cell.title.textColor = UIColor.preferredFioriColor(forStyle: .primaryLabel)
            }
            cell.value = " "
            cell.accessoryType = .disclosureIndicator
            return cell

        default:
            return UITableViewCell()
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 12
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if preventNavigationLoop {
            AlertHelper.displayAlert(with: NSLocalizedString("keyAlertNavigationLoop", value: "No further navigation is possible.", comment: "XTIT: Title of alert message about preventing navigation loop."), error: nil, viewController: self)
            return
        }
        switch indexPath.row {
        case 10:
            if !entity.isNew {
                showFioriLoadingIndicator()
                let destinationStoryBoard = UIStoryboard(name: "SalesOrderHeader", bundle: nil)
                let destinationDetailVC = destinationStoryBoard.instantiateViewController(withIdentifier: "SalesOrderHeaderDetailViewController") as! SalesOrderHeaderDetailViewController
                Task.init {
                    do {
                        try await self.dataService.loadProperty(SalesOrderItem.header, into: self.entity)
                        self.hideFioriLoadingIndicator()
                    } catch {
                        AlertHelper.displayAlert(with: NSLocalizedString("keyErrorLoadingData", value: "Loading data failed!", comment: "XTIT: Title of loading data error pop up."), error: error, viewController: self)
                        return
                    }
                }

                if let header = entity.header {
                    destinationDetailVC.entity = header
                }
                destinationDetailVC.navigationItem.leftItemsSupplementBackButton = true
                destinationDetailVC.navigationItem.title = "Header"
                destinationDetailVC.allowsEditableCells = false
                destinationDetailVC.preventNavigationLoop = true
                navigationController?.pushViewController(destinationDetailVC, animated: true)
            }
        case 11:
            if !entity.isNew {
                showFioriLoadingIndicator()
                let destinationStoryBoard = UIStoryboard(name: "Product", bundle: nil)
                let destinationDetailVC = destinationStoryBoard.instantiateViewController(withIdentifier: "ProductDetailViewController") as! ProductDetailViewController
                Task.init {
                    do {
                        try await self.dataService.loadProperty(SalesOrderItem.productDetails, into: self.entity)
                        self.hideFioriLoadingIndicator()
                    } catch {
                        AlertHelper.displayAlert(with: NSLocalizedString("keyErrorLoadingData", value: "Loading data failed!", comment: "XTIT: Title of loading data error pop up."), error: error, viewController: self)
                        return
                    }
                }

                if let productDetails = entity.productDetails {
                    destinationDetailVC.entity = productDetails
                }
                destinationDetailVC.navigationItem.leftItemsSupplementBackButton = true
                destinationDetailVC.navigationItem.title = "ProductDetails"
                destinationDetailVC.allowsEditableCells = false
                destinationDetailVC.preventNavigationLoop = true
                navigationController?.pushViewController(destinationDetailVC, animated: true)
            }
        default:
            return
        }
    }

    // MARK: - OData property specific cell creators

    private func cellForCurrencyCode(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.currencyCode {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.currencyCode = nil
                    isNewValueValid = true
                } else {
                    if SalesOrderItem.currencyCode.isOptional || newValue != "" {
                        currentEntity.currencyCode = newValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForDeliveryDate(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.deliveryDate {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.deliveryDate = nil
                    isNewValueValid = true
                } else {
                    if let validValue = LocalDateTime.parse(newValue) { // This is just a simple solution to handle UTC only
                        currentEntity.deliveryDate = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForGrossAmount(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.grossAmount {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.grossAmount = nil
                    isNewValueValid = true
                } else {
                    if let validValue = BigDecimal.parse(newValue) {
                        currentEntity.grossAmount = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForItemNumber(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.itemNumber {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.itemNumber = nil
                    isNewValueValid = true
                } else {
                    if let validValue = Int(newValue) {
                        currentEntity.itemNumber = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForNetAmount(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.netAmount {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.netAmount = nil
                    isNewValueValid = true
                } else {
                    if let validValue = BigDecimal.parse(newValue) {
                        currentEntity.netAmount = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForProductID(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.productID {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.productID = nil
                    isNewValueValid = true
                } else {
                    if SalesOrderItem.productID.isOptional || newValue != "" {
                        currentEntity.productID = newValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForQuantity(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.quantity {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.quantity = nil
                    isNewValueValid = true
                } else {
                    if let validValue = BigDecimal.parse(newValue) {
                        currentEntity.quantity = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForQuantityUnit(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.quantityUnit {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.quantityUnit = nil
                    isNewValueValid = true
                } else {
                    if SalesOrderItem.quantityUnit.isOptional || newValue != "" {
                        currentEntity.quantityUnit = newValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForSalesOrderID(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.salesOrderID {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.salesOrderID = nil
                    isNewValueValid = true
                } else {
                    if SalesOrderItem.salesOrderID.isOptional || newValue != "" {
                        currentEntity.salesOrderID = newValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    private func cellForTaxAmount(tableView: UITableView, indexPath: IndexPath, currentEntity: ESPMContainerFmwk.SalesOrderItem, property: Property) -> UITableViewCell {
        var value = ""
        if let propertyValue = currentEntity.taxAmount {
            value = "\(propertyValue)"
        }
        return CellCreationHelper.cellForProperty(tableView: tableView, indexPath: indexPath, entity: entity, property: property, value: value, editingIsAllowed: allowsEditableCells, changeHandler:
            { (newValue: String) -> Bool in
                var isNewValueValid = false
                // The property is optional, so nil value can be accepted
                if newValue.isEmpty {
                    currentEntity.taxAmount = nil
                    isNewValueValid = true
                } else {
                    if let validValue = BigDecimal.parse(newValue) {
                        currentEntity.taxAmount = validValue
                        isNewValueValid = true
                    }
                }
                self.validity[property.name] = isNewValueValid
                self.barButtonShouldBeEnabled()
                return isNewValueValid
            })
    }

    // MARK: - OData functionalities

    @objc func createEntity() {
        showFioriLoadingIndicator()
        view.endEditing(true)
        logger.info("Creating entity in backend.")
        Task.init {
            do {
                try await self.dataService.createEntity(self.entity)
                self.hideFioriLoadingIndicator()
            } catch {
                self.logger.error("Create entry failed. Error: \(error)", error: error)
                AlertHelper.displayAlert(with: NSLocalizedString("keyErrorEntityCreationTitle", value: "Create entry failed", comment: "XTIT: Title of alert message about entity creation error."), error: error, viewController: self)
                return
            }

            self.logger.info("Create entry finished successfully.")
            await MainActor.run {
                self.dismiss(animated: true) {
                    FUIToastMessage.show(message: NSLocalizedString("keyEntityCreationBody", value: "Created", comment: "XMSG: Title of alert message about successful entity creation."))
                    self.tableUpdater?.entitySetHasChanged()
                }
            }
        }
    }

    func createEntityWithDefaultValues() -> ESPMContainerFmwk.SalesOrderItem {
        let newEntity = ESPMContainerFmwk.SalesOrderItem()

        // Key properties without default value should be invalid by default for Create scenario
        if newEntity.itemNumber == nil {
            validity["ItemNumber"] = false
        }
        if newEntity.salesOrderID == nil || newEntity.salesOrderID!.isEmpty {
            validity["SalesOrderId"] = false
        }

        barButtonShouldBeEnabled()
        return newEntity
    }

    @objc func updateEntity(_: AnyObject) {
        showFioriLoadingIndicator()
        view.endEditing(true)
        logger.info("Updating entity in backend.")
        Task.init {
            do {
                try await self.dataService.updateEntity(self.entity)
                self.hideFioriLoadingIndicator()
            } catch {
                self.logger.error("Update entry failed. Error: \(error)", error: error)
                AlertHelper.displayAlert(with: NSLocalizedString("keyErrorEntityUpdateTitle", value: "Update entry failed", comment: "XTIT: Title of alert message about entity update failure."), error: error, viewController: self)
                return
            }

            self.logger.info("Update entry finished successfully.")
            await MainActor.run {
                self.dismiss(animated: true) {
                    FUIToastMessage.show(message: NSLocalizedString("keyUpdateEntityFinishedTitle", value: "Updated", comment: "XTIT: Title of alert message about successful entity update."))
                    self.entityUpdater?.entityHasChanged(self.entity)
                }
            }
        }
    }

    // MARK: - other logic, helper

    @objc func cancel() {
        showFioriLoadingIndicator()
        view.endEditing(true)
        Task.init {
            do {
                try await dataService.loadEntity(entity)
            } catch {
                self.logger.warn("Load entity failed on cancel. Shown cached data may not be reflective of the backend.")
            }
            self.hideFioriLoadingIndicator()
            await MainActor.run {
                self.dismiss(animated: true)
            }
        }
    }

    // Check if all text fields are valid
    private func barButtonShouldBeEnabled() {
        let anyFieldInvalid = validity.values.first { field in
            field == false
        }
        navigationItem.rightBarButtonItem?.isEnabled = anyFieldInvalid == nil
    }
}

extension SalesOrderItemDetailViewController: ESPMContainerEntityUpdaterDelegate {
    func entityHasChanged(_ entityValue: EntityValue?) {
        if let entity = entityValue {
            let currentEntity = entity as! ESPMContainerFmwk.SalesOrderItem
            self.entity = currentEntity
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}
