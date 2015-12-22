
//
//  MasterViewController.m
//  TempleTrip
//
//  Created by Ephraim Kunz on 8/6/15.
//  Copyright (c) 2015 Ephraim Kunz. All rights reserved.
//

#import "MasterViewController.h"
#import "Temple.h"
#import "DetailTableViewController.h"

@import Crashlytics;

#define kFavoritesSection 0 //What section we keep favorite temples in.

@interface MasterViewController ()

@property(strong, nonatomic) NSArray *filteredList;
@property(strong, nonatomic) NSMutableArray *favoritesList;

@end

@implementation MasterViewController
{
	BOOL shouldUpdateFetchedResultsController;
	NSString * sortTableBy;
}

#pragma mark - View Lifecycle
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[Crashlytics sharedInstance] setObjectValue:@"" forKey:@"currentTemple"];
    [[Crashlytics sharedInstance]setIntValue:(int)[self.favoritesList count] forKey:@"numberOfFavorites"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.definesPresentationContext = YES;
    [self setupSearchBar];
	[self loadFavoritesList];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"ShowDetail"]) {
        DetailTableViewController *nextViewController = [segue destinationViewController];
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
		NSManagedObject *object;
		
        if (self.searchController.active) {
            nextViewController.currentTemple = self.filteredList[[indexPath row]];
        }else{
			if (indexPath.section == kFavoritesSection) {
				object = [self.favoritesList objectAtIndex:indexPath.row];
			}
			else{
				NSIndexPath *modified = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
				object = [[self fetchedResultsController] objectAtIndexPath:modified];
			}
            nextViewController.currentTemple = (Temple *)object;
        }
		
		//Create dependency injection: http://stackoverflow.com/questions/21050408/how-to-get-managedobjectcontext-for-viewcontroller-other-than-getting-it-from-ap to pass managedObjectContext along
        
		nextViewController.managedObjectContext = self.managedObjectContext;
		nextViewController.favoritesDelegate = self;
	}
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.searchController.active)
        return 1;
    else
        return [[self.fetchedResultsController sections] count] + 1; // For favorites
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.searchController.active) {
        return [self.filteredList count];
	}else if(section == kFavoritesSection){
		return [self.favoritesList count];
	}else{
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section - 1];
        return [sectionInfo numberOfObjects];
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    if (self.searchController.active) {
        Temple *filteredTemple = [self.filteredList objectAtIndex:[indexPath row]];
        cell.textLabel.text = [filteredTemple name];
        
        //Configure dedication date as detail label.
        NSString *dateCandidate = filteredTemple.dedication;
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
        NSDate *date = [formatter dateFromString:dateCandidate];
        
        if (date) {
            NSString *formattedDate = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
            cell.detailTextLabel.text = formattedDate;
        }
        
        else{
            cell.detailTextLabel.text = filteredTemple.dedication;
        }
    }else{
        [self configureCell:cell atIndexPath:indexPath];
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == kFavoritesSection; // All items in the first section (favorites) will be editable.
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	if (self.searchController.active) {
		return nil; // No names of any sections in the search view.
	}else if(section == kFavoritesSection){
		return @"Favorites";
	}else{
		id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section  - 1];
		return [sectionInfo name];
	}
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView{
	if(self.searchController.active) return nil;
	NSArray *letters = [self.fetchedResultsController sectionIndexTitles];
	NSString *search = UITableViewIndexSearch;
	NSMutableArray *indexTitles = [[NSMutableArray alloc]initWithArray:letters];
	[indexTitles insertObject:search atIndex:0];
	return indexTitles;
	
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index{
	if (index == 0) {
		CGRect searchBarFrame = self.searchController.searchBar.frame;
		[tableView scrollRectToVisible:searchBarFrame animated:NO];
		return -1;
	}
    return [self.fetchedResultsController sectionForSectionIndexTitle:title atIndex:index - 1] + 1; // Because magnifying glass takes up index 0, and we don't have an index icon for favorites.
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		//Fix core data.
		[self removeFavoritesDesignation:self.favoritesList[indexPath.row]];
		//Change the data source for this section
		[self.favoritesList removeObjectAtIndex:indexPath.row];
		//Remove row on the list
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	NSManagedObject *object;
	
	if(indexPath.section == kFavoritesSection){
		object = self.favoritesList[indexPath.row];
	}
	else{
		NSIndexPath *modified = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
		object = [self.fetchedResultsController objectAtIndexPath:modified];
	}
	
    cell.textLabel.text = [[object valueForKey:@"name"] description];
    
    //Configure dedication date as detail label.
    NSString *dateCandidate = [object valueForKey:@"dedication"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    NSDate *date = [formatter dateFromString:dateCandidate];
    
    if (date) {
        NSString *formattedDate = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
        cell.detailTextLabel.text = formattedDate;
    }
    else{
        cell.detailTextLabel.text = [object valueForKey:@"dedication"];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController // Custom getter.
{
    if (_fetchedResultsController != nil && !shouldUpdateFetchedResultsController) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Temple" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"firstLetter" cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
	
	shouldUpdateFetchedResultsController = NO;
	
    _fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    return _fetchedResultsController;
}    



#pragma mark - UISearchResultsUpdating Delegate

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController{
	NSString *searchString = searchController.searchBar.text;
	[self searchForText:searchString];
	[self.tableView reloadData];
}

- (void)searchForText:(NSString *)searchString{
    if (self.managedObjectContext)
    {
		NSFetchRequest *request = [self createSearchFetchRequest];
        NSString *predicateFormat = @"%K CONTAINS[cd] %@";
        NSString *searchAttribute = @"name";
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, searchAttribute, searchString];
        if (![searchString isEqualToString:@""]) {
            [request setPredicate:predicate];
        }
        
        NSError *error = nil;
        self.filteredList = [self.managedObjectContext executeFetchRequest:request error:&error];
    }
}

- (NSFetchRequest *)createSearchFetchRequest{ // Create a new one each time so we can be sure it is "clean" when all text is deleted (returns everything).
	NSFetchRequest *searchFetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Temple" inManagedObjectContext:self.managedObjectContext];
	[searchFetchRequest setEntity:entity];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[searchFetchRequest setSortDescriptors:@[sortDescriptor]];
    
    return searchFetchRequest;
}

#pragma mark - FavoritesDelegate
-(void)addedToFavorites:(Temple*) temple{
	[self loadFavoritesList];
	[self.tableView reloadData];
}

-(void)removedFromFavorites:(Temple*) temple{
	[self loadFavoritesList];
	[self.tableView reloadData];
}

#pragma mark - Utility Methods

- (void)setupSearchBar {
	self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
	self.tableView.tableHeaderView = self.searchController.searchBar;
	self.searchController.searchResultsUpdater = self;
	self.searchController.dimsBackgroundDuringPresentation = NO;
	[self.searchController.searchBar sizeToFit];
}

- (void)loadFavoritesList{
	NSFetchRequest *favoritesFetch = [[NSFetchRequest alloc]initWithEntityName:@"Temple"];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isFavorite == YES"];
	[favoritesFetch setPredicate:predicate];
	
	NSSortDescriptor *alphaName = [[NSSortDescriptor alloc]initWithKey:@"name" ascending:YES];
	[favoritesFetch setSortDescriptors:@[alphaName]];

	NSError *error;
	if(!(self.favoritesList = [NSMutableArray arrayWithArray:[self.managedObjectContext executeFetchRequest:favoritesFetch error:&error]])){
		NSLog(@"Failed to fetch favorites");
	};
}

- (void)removeFavoritesDesignation:(Temple*)temple{
	NSFetchRequest *request = [[NSFetchRequest alloc]initWithEntityName:@"Temple"];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", temple.name];
	[request setPredicate:predicate];
	Temple *object = [self.managedObjectContext executeFetchRequest:request error:nil][0];
	object.isFavorite = [NSNumber numberWithBool:NO];
	[self.managedObjectContext save:nil];
}

@end


