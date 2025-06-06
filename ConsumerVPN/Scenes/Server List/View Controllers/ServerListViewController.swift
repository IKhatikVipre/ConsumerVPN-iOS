//
//  ServerListViewController.swift
//  ConsumerVPN
//
//  Created by WLVPN on 9/15/16.
//  Copyright © 2019 NetProtect. All rights reserved.
//

import UIKit
import VPNKit

final class ServerListViewController: BaseServerTableViewController {
    
    // MARK: Types
    enum RestorationKeys: String {
        case searchControllerIsActive
        case searchBarText
        case searchBarIsFirstResponder
    }
    
    struct SearchControllerRestorableState {
        var wasActive = false
        var wasFirstResponder = false
    }
    
    // MARK: IBOutlets and Variables
    @IBOutlet weak var filterSegmentedControl: UISegmentedControl!
    
    /// Button which makes the search bar the first responder for searching
    var searchButton: UIBarButtonItem!
    
    
    // VPNKit Properties
    var apiManager: VPNAPIManager!

    fileprivate var expandedCountrySectionIndex: Int?
    
    /// Array consisting of ALL City objects transformed into CityModel objects.
    fileprivate var cityModels: [CityModel] = []
    
    /// Array consisting of the sorted and filtered CityModel objects
    fileprivate var sortedModels: [CityModel] = [] {
        didSet {
            // Display the Empty state view if there are no values when there used to be
            if sortedModels.count == 0 { // display empty state
                emptyStateView.isHidden = false
            } else if sortedModels.count != 0 { // remove the empty state
                emptyStateView.isHidden = true
            }
        }
    }
    
    fileprivate var sortedCountrySections = [CountrySection]()
    
    // Sort Options
    fileprivate var sortOption = SortOption.country
    
    // All Sort options. This will be passed forward to FilterViewController
    fileprivate let fSortByOptions: [SortOption] = [.city, .country]

    // Searching Behavior
    fileprivate var searchController: UISearchController!
    /// Used to display the filtered search results using the SearchController
    fileprivate var resultsServerViewController: ResultsServerViewController!
    fileprivate var restoredState = SearchControllerRestorableState()
    
    /// View which contains information on why the user is looking at an empty state on the table view and acts as the background when the `filteredModels` array contains 0 elements
    fileprivate var emptyStateView: EmptyStateView!
    
    var presentedModally = false
    
    // MARK: Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the navbar
        searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchButtonTapped(_:)))
        
        
        var isSearchBtnNeeded: Bool {
            if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
                return false
            }
            else {
                return true
            }
        }
        
        if isSearchBtnNeeded {
            navigationItem.rightBarButtonItem = searchButton
        }
        
        Bundle.main.loadNibNamed("FilterNavBar", owner: self, options: nil)
        navigationItem.titleView = filterSegmentedControl
        if #available(iOS 13.0, *) {
            filterSegmentedControl.selectedSegmentTintColor = .segmentedControlTint
        }
        else {
            filterSegmentedControl.tintColor = .segmentedControlTint
        }
        
        
        let selectedAttributes: [NSAttributedString.Key: UIColor] = [
            .foregroundColor: .serverNavigationBarItemTint
        ]
        
        filterSegmentedControl.setTitleTextAttributes(selectedAttributes, for: .selected)
        filterSegmentedControl.setTitleTextAttributes(selectedAttributes, for: .normal)
        
        view.backgroundColor = .viewBackground
        tableView.backgroundColor = .serverListBackground
        
        // assign our remembered info about sorting from NSUserDefaults
        sortOption = fSortByOptions[UserDefaults.standard.integer(forKey: Theme.sortOptionKey)]
        
        // setup accessibility and localization
        setupAccessibilityAndLocalization()
        
        // Setup the Empty State View
        if let emptyStateView = Bundle.main.loadNibNamed(EmptyStateView.nibName, owner: self, options: nil)?.first as? EmptyStateView {
            // configure the empty state view visually
            emptyStateView.frame = tableView.frame
            emptyStateView.isHidden = true
            tableView.backgroundView = emptyStateView
            // assign its delegate
            emptyStateView.delegate = self
            // keep a strong reference to it
            self.emptyStateView = emptyStateView
        }
        
        // Create and setup the Results View Controller where our search results will be displayed
        resultsServerViewController = ResultsServerViewController()
        // provide the results controller with the current searchText for its empty state view
        resultsServerViewController.searchText = ""
        
        // We want to be the delegate for our filtered table so didSelectRowAtIndexPath(_:) is called for both tables and any header actions
        resultsServerViewController.tableView.delegate = self
        
        // Setup the SearchController and the SearchController's searchBar
        searchController = UISearchController(searchResultsController: resultsServerViewController)
        searchController.searchResultsUpdater = self
        
        // set some options in preparation for the searchController
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.barStyle = .black
        searchController.searchBar.barTintColor = .serverListBackground
        
        // Customize the cancel button color
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(selectedAttributes, for: .normal)
        
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            tableView.tableHeaderView = searchController.searchBar
            // Shift the searchBar to just under the navigation bar (not visible by default)
            tableView.contentOffset = CGPoint(x: 0, y: searchController.searchBar.frame.height)
        }
        
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.primaryText]
        
        definesPresentationContext = true
        
        // Listen for VPNKit Notifications
        NotificationCenter.default.addObserver(for: self)
        
        refreshControl = UIRefreshControl()
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(refreshList(_:)), for: .valueChanged)
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    /// Helper method responsible for setting the accessibility labels and identifiers as well as localizations with our UI
    fileprivate func setupAccessibilityAndLocalization() {
        searchButton.accessibilityLabel = AccessibilityLabel.searchButton
//        filterButton.accessibilityLabel = AccessibilityLabel.filterButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // provide the empty state view with the current information
        emptyStateView.searchText = searchController.searchBar.text ?? ""
        
        // reload the tableView
        updateCities()
        
        if presentedModally {
            let closeButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(returnToDashboard))
            navigationItem.leftBarButtonItem = closeButton
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Restore the searchController's active state
        if restoredState.wasActive {
            searchController.isActive = restoredState.wasActive
            restoredState.wasActive = false
            
            if restoredState.wasFirstResponder {
                searchController.searchBar.becomeFirstResponder()
                restoredState.wasFirstResponder = false
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // show the navigation bar just in case it was gone when the user made a selection
        if let isNavigationBarHidden = navigationController?.isNavigationBarHidden,
            isNavigationBarHidden == true {
            navigationController?.setNavigationBarHidden(false, animated: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If we're going to the filter view controller, assign it's delegate, the current ping and sort options, and the collection that it will display
        if let filterViewController = segue.destination as? FilterViewController {
            filterViewController.delegate = self
            filterViewController.selectedSortOption = sortOption
            filterViewController.fSortByOptions = fSortByOptions
        }
    }
    
    // MARK: IBActions
    @objc func refreshList(_ sender: AnyObject) {
        ApiManagerHelper.shared.refreshServer { [weak self] success, error in
            guard let `self` = self else { return }
            if success {
                self.updateCities()
            } else {
                if let updateServerError = error {
                    self.present(UIAlertController.contactSupport(with: updateServerError), animated: true, completion: nil)
                } else {
                    if !ApiManagerHelper.shared.isNetworkReachable() {
                        self.present(UIAlertController.network(), animated: true, completion: nil)
                    }
                    debugPrint("[ConsumerVPN] Server update failed without error")
                }
            }
            self.refreshControl?.endRefreshing()
        }
    }
    
    @objc func searchButtonTapped(_ sender: UIBarButtonItem) {
        searchController.searchBar.becomeFirstResponder()
    }
    
    @IBAction func filterSelected(_ sender: Any) {
        tableView.reloadData()
    }
    
    @objc fileprivate func returnToDashboard() {
        // go back to the dashboard
        if presentedModally {
            dismiss(animated: true, completion: nil)
        } else {
            tabBarController?.selectedIndex = 0
        }
    }

    // MARK: - UITableViewDataSoure
    override func numberOfSections(in tableView: UITableView) -> Int {
        if filterSegmentedControl.selectedSegmentIndex == 0 {
            return sortedCountrySections.count + 1
        } else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Need to provide room for best available
        if tableView === self.tableView {
            if filterSegmentedControl.selectedSegmentIndex == 0 {
                if let sectionIndex = expandedCountrySectionIndex,
                    section == sectionIndex {
                    if section == 0 {
                        return 0
                    }
                    return sortedCountrySections[sectionIndex - 1].cities.count
                } else {
                    return 0
                }
            } else {
                return sortedModels.count + 1
            }
        } else {
            return sortedModels.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // we should crash if this isn't hooked up properly. Allows for easy debugging
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CityServerTableViewCell.reuseIdentifier, for: indexPath) as? CityServerTableViewCell else {
            abort()
        }
        
        let cityModel: CityModel?
        
        if tableView == self.tableView {
            if (filterSegmentedControl.selectedSegmentIndex == 0) {
                cityModel = sortedCountrySections[indexPath.section - 1].cities[indexPath.row]
                configureCityOnly(cell, forCityModel: cityModel!)
            } else {
                if indexPath.row == 0 {
                    configureBestAvailable(cell)
                } else {
                    cityModel = sortedModels[indexPath.row - 1]
                    configure(cell, forCityModel: cityModel!)
                }
            }
        } else {
            cityModel = resultsServerViewController.sortedCityModels[indexPath.row]
            configure(cell, forCityModel: cityModel!)
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // update the vpnConfiguration based on the selection and bring the user back to the dashboard
        // We're handling both the ServerListViewController's table and ResultsServerViewController here
        var cityModel: CityModel?
        if tableView === self.tableView {
            if filterSegmentedControl.selectedSegmentIndex == 0 {
                cityModel = sortedCountrySections[indexPath.section - 1].cities[indexPath.row]
            } else {
                if indexPath.row != 0 {
                    cityModel = sortedModels[indexPath.row - 1]
                }
            }
        } else {
            cityModel = resultsServerViewController.sortedCityModels[indexPath.row]
        }
        if !ApiManagerHelper.shared.isVPNConnectionInProgress() {
            connectOnSelection {
                ApiManagerHelper.shared.selectServerWith(cityModel: cityModel)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        // Remove the header if we are viewing the search results
        if tableView != self.tableView {
            return nil
        }
        
        if filterSegmentedControl.selectedSegmentIndex == 0 {
            guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: CountryHeaderView.reuseIdentifier) as? CountryHeaderView else {
                abort()
            }
			        
            header.sectionIndex = section
            header.cityButton.addTarget(self, action: #selector(expandCountry(_:)), for: .touchUpInside)
            
            let tapRecognizer = CountryTapGesture(target: self, action: #selector(countrySelected(_:)))
            tapRecognizer.numberOfTapsRequired = 1

            if section == 0 {
                configureBestAvailable(header)
                tapRecognizer.country = nil
            } else {
                configure(header, forCountrySection: sortedCountrySections[section - 1])
                tapRecognizer.country = sortedCountrySections[section - 1].cities.first?.city.country
            }
            header.addGestureRecognizer(tapRecognizer)
            return header
        } else {
            return nil // blank view to remove section header
        }
    }
    
    @objc func expandCountry(_ sender: UIButton) {
        guard let headerView = sender.superview as? CountryHeaderView else {
            return
        }
        
        var indexPathsToRemove = [IndexPath]()
        var indexPathsToAdd = [IndexPath]()
        
        if let sectionToExpand = headerView.sectionIndex {
            var sameIndex = false
            if let alreadyExpandedSection = expandedCountrySectionIndex {
                if alreadyExpandedSection == sectionToExpand {
                    sameIndex = true
                }
                expandedCountrySectionIndex = nil
                
                for row in 0..<sortedCountrySections[alreadyExpandedSection - 1].cities.count {
                    let indexPath = IndexPath(row: row, section: alreadyExpandedSection)
                    indexPathsToRemove.append(indexPath)
                }
            }
            if !sameIndex {
                expandedCountrySectionIndex = sectionToExpand
                for row in 0..<sortedCountrySections[sectionToExpand - 1].cities.count {
                    let indexPath = IndexPath(row: row, section: sectionToExpand)
                    indexPathsToAdd.append(indexPath)
                }
            }
        }
        
        tableView.beginUpdates()
        if indexPathsToRemove.count > 0 {
            tableView.deleteRows(at: indexPathsToRemove, with: .automatic)
        }
        if indexPathsToAdd.count > 0 {
            tableView.insertRows(at: indexPathsToAdd, with: .automatic)
        }
        tableView.endUpdates()
    }
    
    class CountryTapGesture: UITapGestureRecognizer {
        var country: Country?
    }
    
    func connectOnSelection(updateVPNConfig: @escaping () ->()) {
        if ApiManagerHelper.shared.isConnectedToVPN()  {
            
            let title = LocalizedString.preferencesHeader
            let message = LocalizedString.applyChangeReconnect
            var actions : [UIAlertAction] = []
            
            var action = UIAlertAction(title: LocalizedString.cancel, style: .cancel,handler: { (action) in
               
            })
            actions.append(action)
            
            action = UIAlertAction(title: LocalizedString.reconnect, style: .default,handler: { [unowned self] (action) in
                ApiManagerHelper.shared.disconnect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { /*[weak self] in*/
                    updateVPNConfig()
                    ApiManagerHelper.shared.toggleOnDemand(enable: false, reconnect: true)
                }
                returnToDashboard()
            })
            actions.append(action)
            
            if ApiManagerHelper.shared.isOnDemandEnabled {
                action = UIAlertAction(title: LocalizedString.disconnect, style: .destructive,handler: { [unowned self] (action) in
                    ApiManagerHelper.shared.disconnect()
                    updateVPNConfig()
                    ApiManagerHelper.shared.setOnDemand(enable: false)
                    self.returnToDashboard()
                })
                actions.append(action)
            }
            
            let alert = UIAlertController.alert(withTitle: title, message: message, actions: actions, alertType: .alert)
            present(alert, animated: true, completion: nil)
            
        } else {
            updateVPNConfig()
            if ApiManagerHelper.shared.isOnDemandEnabled {
                ApiManagerHelper.shared.synchronizeConfiguration()
            } else {
                ApiManagerHelper.shared.connect()
            }
            returnToDashboard()
        }
    }
    
    @objc private func countrySelected(_ sender: CountryTapGesture) {
        if !ApiManagerHelper.shared.isVPNConnectionInProgress() {
            connectOnSelection {
                ApiManagerHelper.shared.selectServerWith(country: sender.country)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        // Hide the header if we are viewing search results
        if tableView != self.tableView {
            return 0.0
        }
        
        return (filterSegmentedControl.selectedSegmentIndex == 0) ? 54.0 : 0.0
    }
    
    // MARK - UIStateRestoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        // Encode the view state so it can be restored later
        
        // Encode the searchController's active state
        coder.encode(searchController.isActive, forKey: RestorationKeys.searchControllerIsActive.rawValue)
        
        // Encode the first responder status
        coder.encode(searchController.searchBar.isFirstResponder, forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)
        
        // Encode the search bar text
        coder.encode(searchController.searchBar.text, forKey: RestorationKeys.searchBarText.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        // Restore the active state
        // We can't make the searchController active here since it's not part of the view hierarchy yet.
            // Instead, we do this in viewWillAppear
        restoredState.wasActive = coder.decodeBool(forKey: RestorationKeys.searchControllerIsActive.rawValue)
        
        // Restore the first responder status.
        // Same as above, we do this in viewWillAppear
        restoredState.wasFirstResponder = coder.decodeBool(forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)
        
        // Restore the text in the search bar
        searchController.searchBar.text = coder.decodeObject(forKey: RestorationKeys.searchBarText.rawValue) as? String
    }
}

// MARK: - FilterViewControllerDelegate
extension ServerListViewController: FilterViewControllerDelegate {
    
    func filterViewController(_ filterViewController: FilterViewController, selected sortOption: SortOption) {
        self.sortOption = sortOption
        
        // Save this to UserDefaults
        UserDefaults.standard.set(fSortByOptions.firstIndex(of: sortOption) ?? 0, forKey: Theme.sortOptionKey)
    }
}

// MARK: - UISearchBarDelegate
extension ServerListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Update the results controller's empty state view to have most up to date search text
        // Our empty state view doesn't need this info as it will never be displayed when there is text
        resultsServerViewController.searchText = searchText
    }
    
}

// MARK: - UISearchResultsUpdating
extension ServerListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        
        // Just because the searchController is active does not mean its content is displayed. Because of this, we should only work with it if
            // it is both active and the searchBar has text
        
        // Strip out all the leading and trailing spaces
        let searchText = searchController.searchBar.text ?? ""
        let strippedString = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let isSearchTableDisplayed = searchController.isActive && strippedString.hasText
        
        if isSearchTableDisplayed {
            // Filter our reference point down using what options the user has set and pass off to the search results controller
            guard let resultsController = searchController.searchResultsController as? ResultsServerViewController else {
                return
            }
            resultsController.sortedCityModels = cityModels.filtered(withName: strippedString)
                                                           .sorted(by: sortOption)
            
            // reload the table with the changes
            resultsController.tableView.reloadData()
            
        } else {
            // Filter our reference point down using only the filter options and sort options and display on main table view
            sortedModels = cityModels.filtered(withName: strippedString)
                                     .sorted(by: sortOption)
            
            // reload our table with the changes
            tableView.reloadData()
        }
    }
}

// MARK: - EmptyStateViewDelegate
extension ServerListViewController: EmptyStateViewDelegate {
    func reloadServersTapped(in emptyStateView: EmptyStateView) {
        // this should never happen from the results view controller, but just make sure anyway
        guard emptyStateView === self.emptyStateView else {
            return
        }
        
        ApiManagerHelper.shared.refreshServer { [weak self] success, error in
            
            guard let `self` = self else { return  }
            if success {
                updateCities()
            } else {
                if let updateServerError = error {
                    present(UIAlertController.contactSupport(with: updateServerError), animated: true, completion: nil)
                } else {
                    if !ApiManagerHelper.shared.isNetworkReachable() {
                        self.present(UIAlertController.network(), animated: true, completion: nil)
                    }
                    debugPrint("[ConsumerVPN] Server update failed without error")
                }
                
                emptyStateView.reloadServersButton?.isEnabled = true
            }
        }
    }
    
    func updateCities() {
        
        self.cityModels = ApiManagerHelper.shared.fetchCities()
        
        // 2. filter/sort using filteroptions into local variable and then diff against displayed filtered info.
        let sections = Dictionary(grouping: self.cityModels) { $0.countryName }
        sortedCountrySections = sections.map(CountrySection.init(country:cities:)).sorted()
        
        // Depending on which table is being displayed (ServerList - main table, ResultsController - search table),
        // update that data model and tableter
        let searchText = searchController.searchBar.text ?? ""
        let isSearchTableDisplayed = searchController.isActive && searchText.hasText
        
        if isSearchTableDisplayed {
            resultsServerViewController.sortedCityModels = self.cityModels.sorted(by: sortOption)
            resultsServerViewController.tableView.reloadData()
        } else {
            sortedModels = self.cityModels.sorted(by: sortOption)
            tableView.reloadData()
        }
    }
}

extension ServerListViewController: StoryboardInstantiable {
    
    static var storyboardName: String {
        return "ServerList"
    }
    
    class func build(with apiManager: VPNAPIManager) -> ServerListViewController {
        let servVC = instantiateInitial()
        servVC.apiManager = apiManager
        return servVC
    }
}

// MARK: - VPNConnectionStatusReporting
extension ServerListViewController : VPNStatusReporting {
}
