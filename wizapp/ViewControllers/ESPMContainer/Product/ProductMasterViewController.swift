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

class ProductMasterViewController: FUIFormTableViewController, SAPFioriLoadingIndicator {
    var dataService: ESPMContainer!
    public var loadEntitiesBlock: (() async throws -> [ESPMContainerFmwk.Product])?
    private var entities: [ESPMContainerFmwk.Product] = .init()
    private var entityMedia = [ESPMContainerFmwk.Product.ID: Data]()
    private let logger = Logger.shared(named: "ProductMasterViewControllerLogger")
    private let okTitle = NSLocalizedString("keyOkButtonTitle",
                                            value: "OK",
                                            comment: "XBUT: Title of OK button.")
    var loadingIndicator: FUILoadingIndicatorView?
    private let dispatchGroup = DispatchGroup()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Add refreshcontrol UI
        refreshControl?.addTarget(self, action: #selector(refresh), for: UIControl.Event.valueChanged)
        tableView.addSubview(refreshControl!)
        // Cell height settings
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 98
        updateTable()
    }

    var preventNavigationLoop = false
    var entitySetName: String?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return entities.count
    }

    override func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let product = entities[indexPath.row]

        let cell = CellCreationHelper.objectCellWithNonEditableContent(tableView: tableView, indexPath: indexPath, key: "ProductId", value: "\(product.productID!)")
        cell.preserveDetailImageSpacing = true
        if let media = media(for: indexPath, product: entities[indexPath.row]),
           let image = UIImage(data: media)
        {
            cell.detailImage = image
            cell.detailImageView.contentMode = .scaleAspectFit
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle != .delete {
            return
        }
        let currentEntity = entities[indexPath.row]
        Task.init {
            do {
                try await self.dataService.deleteEntity(currentEntity)
            } catch {
                self.logger.error("Delete entry failed.", error: error)
                AlertHelper.displayAlert(with: NSLocalizedString("keyErrorDeletingEntryTitle", value: "Delete entry failed", comment: "XTIT: Title of deleting entry error pop up."), error: error, viewController: self)
                return
            }

            self.entities.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // MARK: - Data accessing

    func requestEntities() async throws {
        entities = try await loadEntitiesBlock!().sorted(by: { ($0.productID!) < ($1.productID!) })
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showDetail" {
            // Show the selected Entity on the Detail view
            guard let indexPath = tableView.indexPathForSelectedRow else {
                return
            }
            logger.info("Showing details of the chosen element.")
            let selectedEntity = entities[indexPath.row]
            let detailViewController = segue.destination as! ProductDetailViewController
            detailViewController.entity = selectedEntity
            detailViewController.entityMedia = media(for: indexPath, product: selectedEntity)
            detailViewController.navigationItem.leftItemsSupplementBackButton = true
            detailViewController.navigationItem.title = entities[(tableView.indexPathForSelectedRow?.row)!].productID ?? ""
            detailViewController.allowsEditableCells = false
            detailViewController.tableUpdater = self
            detailViewController.tableMediaUpdater = self
            detailViewController.preventNavigationLoop = preventNavigationLoop
            detailViewController.dataService = dataService
            detailViewController.entitySetName = entitySetName
        } else if segue.identifier == "addEntity" {
            // Show the Detail view with a new Entity, which can be filled to create on the server
            logger.info("Showing view to add new entity.")
            let dest = segue.destination as! UINavigationController
            let detailViewController = dest.viewControllers[0] as! ProductDetailViewController
            detailViewController.title = NSLocalizedString("keyAddEntityTitle", value: "Add Entity", comment: "XTIT: Title of add new entity screen.")
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: detailViewController, action: #selector(detailViewController.createEntity))
            detailViewController.navigationItem.rightBarButtonItem = doneButton
            let cancelButton = UIBarButtonItem(title: NSLocalizedString("keyCancelButtonToGoPreviousScreen", value: "Cancel", comment: "XBUT: Title of Cancel button."), style: .plain, target: detailViewController, action: #selector(detailViewController.cancel))
            detailViewController.navigationItem.leftBarButtonItem = cancelButton
            detailViewController.allowsEditableCells = true
            detailViewController.tableUpdater = self
            detailViewController.tableMediaUpdater = self
            detailViewController.dataService = dataService
            detailViewController.entitySetName = entitySetName
        }
    }

    // MARK: - Media loading

    private func media(for indexPath: IndexPath, product: Product) -> Data? {
        if let media = entityMedia[entities[indexPath.row].id] {
            return media
        } else {
            showFioriLoadingIndicator()
            dispatchGroup.enter()
            Task.init {
                defer {
                    self.dispatchGroup.leave()
                }
                do {
                    let media = try await self.dataService.downloadMedia(entity: product)
                    // store the downloaded image
                    self.entityMedia[self.entities[indexPath.row].id] = media
                } catch {
                    self.logger.error("Download media failed.", error: error)
                    return
                }
            }
            dispatchGroup.notify(queue: .main) {
                // update the cell
                self.tableView.beginUpdates()
                guard let media = self.entityMedia[self.entities[indexPath.row].id] else {
                    return
                }
                if let image = UIImage(data: media), let cell = self.tableView.cellForRow(at: indexPath) as? FUIObjectTableViewCell {
                    cell.detailImage = image
                    cell.detailImageView.contentMode = .scaleAspectFit
                }
                self.tableView.endUpdates()
                self.hideFioriLoadingIndicator()
            }
            return nil
        }
    }

    // MARK: - Table update

    func updateTable() {
        showFioriLoadingIndicator()
        Task.detached {
            await self.loadData()
            self.hideFioriLoadingIndicator()
        }
    }

    private func loadData() async {
        do {
            try await requestEntities()
        } catch {
            AlertHelper.displayAlert(with: NSLocalizedString("keyErrorLoadingData", value: "Loading data failed!", comment: "XTIT: Title of loading data error pop up."), error: error, viewController: self)
            logger.error("Could not update table.", error: error)
            return
        }
        await MainActor.run {
            self.tableView.reloadData()
            self.logger.info("Table updated successfully!")
        }
    }

    @objc func refresh() {
        Task.detached {
            await self.loadData()
            await MainActor.run {
                self.refreshControl?.endRefreshing()
            }
        }
    }
}

extension ProductMasterViewController: ESPMContainerEntitySetUpdaterDelegate {
    func entitySetHasChanged() {
        updateTable()
    }
}

extension ProductMasterViewController: ESPMContainerEntitySetMediaUpdaterDelegate {
    func entitySetMediaHasChanged(for entity: SAPOData.EntityValue?, to media: Data?) {
        if let changedEntity = entity as? ESPMContainerFmwk.Product, let changedMedia = media {
            entityMedia[changedEntity.id] = changedMedia
        }
        updateTable()
    }
}
