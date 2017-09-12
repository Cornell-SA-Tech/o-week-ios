//
//  Internet.swift
//
//  Created by David Chu on 2017/4/23.
//  Copyright © 2017 Cornell D&TI. All rights reserved.
//

import UIKit
import SystemConfiguration

/**
 Handles ALL web-related activities for this app.
 - important: No over-the-web connections should be made outside of this class.
 */
class Internet
{
	//Link to the website where all event info is stored.
    static let DATABASE = "https://oweekapp.herokuapp.com/flow/"
    
    //suppress default constructor for noninstantiability
    private init(){}
	
	/**
	
	Downloads all events and categories to update the app to the database's newest version.
	The `onCompletion` provided will be executed when the data has been processed.
	
	- Note: `UserData.selectedEvents` will not be updated by this method.
	- Requires: `UserData.categories` and `UserData.allEvents` should already be filled with events loaded from `CoreData`.
	
	Expected JSON structure:
	
		{
	 		version: Int,
			categories:
			{
				changed: [Category.init(jsonOptional:[String:Any]), category2, ...],
				deleted: [Category.pk, pk2, ...]
			},
			events:
			{
				changed: [Event.init(jsonOptional:[String:Any])}, event2, ...],
				deleted: [Event.pk, pk2, ...]
			}
		}
	
	- Parameters:
		- version: Current version of database on file. Should be 0 if never downloaded from database.
		- finish: Function to execute when data is processed.
	*/
	static func getUpdatesForVersion(_ version:Int, onCompletion finish:@escaping (() -> ()))
	{
		get(url: "\(DATABASE)version/\(version)", handler:
		{
			json in
			
			guard let data = json as? [String:Any],
					let newestVersion = data["version"] as? Int,
					let categories = data["categories"] as? [String:Any],
					let changedCategories = categories["changed"] as? [Any],
					let deletedCategories = categories["deleted"] as? [Int],
					let events = data["events"] as? [String:Any],
					let changedEvents = events["changed"] as? [Any],
					let deletedEvents = events["deleted"] as? [Int] else {
				return
			}
			
			//quick exit if version # did not change
			guard version != newestVersion else {
				return
			}
			
			//note: flatMap can also remove nils
			//update categories
			changedCategories.map({Category(jsonOptional: $0 as? [String:Any])})
				.flatMap({$0})
				.forEach({UserData.updateCategory($0)})
			//remove categories
			var newCategories = [Category]()
			for category in UserData.categories
			{
				if (deletedCategories.contains(category.pk))
				{
					UserData.removeFromCoreData(category)
				}
				else
				{
					newCategories.append(category)
				}
			}
			UserData.categories = newCategories
			
			//keep track of all changed events to notify the user
			var changedEventsTitles = [String]()
			//update events
			changedEvents.map({Event(jsonOptional: $0 as? [String:Any])})
				.flatMap({$0})
				.forEach({
					event in
					changedEventsTitles.append(event.title)
					UserData.updateEvent(event)
				})
			//delete events
			for date in UserData.DATES
			{
				var newEventsForDate = [Event]()
				for event in UserData.allEvents[date]!
				{
					if (deletedEvents.contains(event.pk))
					{
						changedEventsTitles.append(event.title)
						UserData.removeFromCoreData(event)
					}
					else
					{
						newEventsForDate.append(event)
					}
				}
				UserData.allEvents[date] = newEventsForDate
				UserData.selectedEvents[date] = UserData.selectedEvents[date]!.filter({!deletedEvents.contains($0.pk)})
			}
			
			UserData.version = newestVersion
			finish()
			
			//notify classes that need to know when events were udpated
			runAsyncFunction({NotificationCenter.default.post(name: .reloadData, object: nil)})
			print(changedEventsTitles)
			LocalNotifications.addNotification(for: changedEventsTitles)
		})
	}
	/**
	Sets an image corresponding to `event` into `imageView`. Attempts to retrieve image from saved files first, then attempts to downlaod image if no saved file exists.
	
	- Parameters:
		- event: Event whose image we must fetch.
		- imageView: View to display the image.
	*/
    static func getImageFor(_ event:Event, imageView:UIImageView)
    {
		if let image = UserData.loadImageFor(event)
		{
			imageView.image = image
		}
		else
		{
			imageFrom("\(DATABASE)event/\(event.pk)/image", imageView: imageView, event: event)
		}
    }
	/**
	Downloads an image from the url, then sets the image downloaded to `imageView` and saves the image such that it can be retreived from disk with `event` next time the image is requested.
	- Note: The download is done asynchronously as required for all internet connections in iOS. This undoubtedly means the user may see some "lag" while the image is downloading.
	- Parameters:
		- urlString: URL of image to download.
		- imageView: View to display the image.
		- event: Event that will be associated with the image once it is saved.
	*/
	private static func imageFrom(_ urlString:String, imageView:UIImageView, event:Event)
    {
        guard let url = URL(string: urlString) else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler:
        {
            data, response, error in
            
            //only parse data if it exists
            if (data != nil && data!.count != 0)
            {
                if let downloadedImage = UIImage(data: data!)
                {
                    runAsyncFunction({imageView.image = downloadedImage})
					UserData.saveImage(downloadedImage, event: event)
                }
            }
        })
        task.resume()
    }
    /**
     Sends a GET request to the`url` with the given keys, retrieves a JSON object, then runs `handler` with the JSON object when it is done. Always use this function to communicate with the server.
     - Parameters:
     	- url: URL to send the GET request to
     	- handler: A function used to process the info returned from the database
     */
    private static func get(url:String, handler:((Any?) -> ())?)
    {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request, completionHandler:
        {
            data, response, error in
            
            //only parse data if it exists
            if (data != nil && data!.count != 0)
            {
                do
                {
                    let info = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    handler?(info)
                    return
                }
                catch
                {
                    print("Internet: unwrapping from JSON error")
                }
            }
            handler?(nil)
        })
        task.resume()
    }
    /**
     Runs `function` asynchronously. Use when attempting to modify UI from functions that involve internet connections. This is required because the UI thread must be independent from the internet threads in iOS, and not using this function will result in an exception.
     - parameter function: Function to run
     */
    private static func runAsyncFunction(_ function:(() -> ())?)
    {
        if (function == nil) {
            return
        }
        DispatchQueue.main.async(execute: {
            function?()
        })
    }
}
