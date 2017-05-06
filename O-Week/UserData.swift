//
//  UserData.swift
//  O-Week
//
//  Created by Vicente Caycedo on 4/28/17.
//  Copyright © 2017 Cornell SA Tech. All rights reserved.
//
//  Holds user's added events

import Foundation
import CoreData

class UserData {
    
    //Settings
    static let allSettings: [(name: String, options: [String])] = [(name: "Receive reminders for...", options: ["No events", "All my events", "Only required events"]), (name: "Notify me...", options: ["At time of event", "1 hour before", "2 hours before", "3 hours before", "5 hours before", "Morning of (7 am)", "1 day before", "2 days before"])]
    
    //Events
    static var allEvents: [Event] = []
    static var selectedEvents:Set<Event> = Set()
    
    //Calendar 
    static let userCalendar = Calendar.current
    
    //Dates 
    // FIXME
    static let dates = ["19", "20", "21", "22", "23", "24", "25", "26", "27", "28"]
    static let days = ["FRI", "SAT", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    private init(){}
}
