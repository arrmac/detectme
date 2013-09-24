//
//  GalleryViewController.m
//  DetecTube
//
//  Created by Josep Marc Mingot Hidalgo on 16/09/13.
//  Copyright (c) 2013 Josep Marc Mingot Hidalgo. All rights reserved.
//

#import "GalleryViewController.h"
#import "DetectorFetcher.h"
#import "DetectorCell.h"
#import "Author.h"
#import "Detector+Server.h"
#import "ExecuteDetectorViewController.h"


@implementation GalleryViewController


#pragma mark -  
#pragma mark Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];
//    self.debug = YES;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(!self.detectorDatabase){
        NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        url = [url URLByAppendingPathComponent:@"Default Detector Database"];
        self.detectorDatabase = [[UIManagedDocument alloc] initWithFileURL:url];
    }
}


#pragma mark -
#pragma mark Getters and Setters


- (void) setDetectorDatabase:(UIManagedDocument *)detectorDatabase
{
    if(_detectorDatabase != detectorDatabase){
        _detectorDatabase = detectorDatabase;
        [self useDocument]; //Populate the database.
    }
}


#pragma mark -
#pragma mark IBActions

- (IBAction)privateAction:(UISegmentedControl *)segmentedControl
{
    if (segmentedControl.selectedSegmentIndex == 0)
        [self fetchAll];
    else
        [self fetchResultsForPredicate:[NSPredicate predicateWithFormat:@"isPublic == NO"]];
}

#pragma mark -
#pragma mark UISearchDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // The user clicked the [X] button or otherwise cleared the text.
    if([searchText length] == 0) {
        [self fetchAll];
        [searchBar performSelector: @selector(resignFirstResponder)
                        withObject: nil
                        afterDelay: 0.1];
    }else
        [self fetchResultsForPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR targetClass CONTAINS[cd] %@", searchText, searchText]];
}


#pragma mark -
#pragma mark UICollectionView DataSource & Delegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    DetectorCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"DetectorCell" forIndexPath:indexPath];
    Detector *detector = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [cell.label setText:detector.name];
    cell.imageView.image = [UIImage imageWithData:detector.image];
    
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
//    Detector *detector = [self.fetchedResultsController objectAtIndexPath:indexPath];
//    [self performSegueWithIdentifier: @"ShowDetectorDetails" sender: self];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: Deselect item
}


// Layout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //    NSString *searchTerm = self.searches[indexPath.section]; FlickrPhoto *photo = self.searchResults[searchTerm][indexPath.row];
    //    CGSize retval = photo.thumbnail.size.width > 0 ? photo.thumbnail.size : CGSizeMake(100, 100);
    //    retval.height += 35; retval.width += 35;
    
    CGSize retval = CGSizeMake(100, 100);
    return retval;
}


//- (UIEdgeInsets)collectionView: (UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
//{
//    return UIEdgeInsetsMake(0,0,0,0);//(50, 10, 50, 10);
//}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ExecuteDetector"]) {
        NSIndexPath *indexPath = [[self.collectionView indexPathsForSelectedItems] lastObject];
        Detector *detector = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        [(ExecuteDetectorViewController *)segue.destinationViewController setDetector:detector];
    }
}

#pragma mark -
#pragma mark Private methods

- (void) fetchResultsForPredicate:(NSPredicate *)predicate
{
    // Everything that happens in this context is automatically hooked to the table
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Detector"];
    if(predicate){ request.predicate = predicate; NSLog(@"predicate");}
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:self.detectorDatabase.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
}

- (void) fetchAll
{
    [self fetchResultsForPredicate:nil];
}


- (void) fetchDetectorsDataIntoDocument:(UIManagedDocument *) document
{
    // Populate the table if not
    // |document| as an argument for thread safe: someone could change the propertie in parallel
    dispatch_queue_t fetchQ = dispatch_queue_create("Detectors Fetcher", NULL);
    dispatch_async(fetchQ, ^{
        NSArray *detectors = [DetectorFetcher fetchDetectorsSync];
        [document.managedObjectContext performBlock:^{
            [Detector removePublicDetectorsInManagedObjectContext:document.managedObjectContext];
            for(NSDictionary *detectorInfo in detectors){
                //start creating objects in document's context
                [Detector detectorWithDictionaryInfo:detectorInfo inManagedObjectContext:document.managedObjectContext];
            }
        }];
    });
}


- (void) useDocument
{
    // create DB if it does not exist in disk
    if(![[NSFileManager defaultManager] fileExistsAtPath:[self.detectorDatabase.fileURL path]]){
        [self.detectorDatabase saveToURL:self.detectorDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            [self fetchAll];
            [self fetchDetectorsDataIntoDocument:self.detectorDatabase];
        }];
        
    }else if (self.detectorDatabase.documentState == UIDocumentStateClosed){ //open DB if it was close
        [self.detectorDatabase openWithCompletionHandler:^(BOOL success) {
            [self fetchAll];
            [self fetchDetectorsDataIntoDocument:self.detectorDatabase];
        }];
        
    }else if (self.detectorDatabase.documentState == UIDocumentStateNormal){
        [self fetchAll]; //
        [self fetchDetectorsDataIntoDocument:self.detectorDatabase];
    }
}

- (void)viewDidUnload {
    [self setCollectionView:nil];
    [super viewDidUnload];
}

@end