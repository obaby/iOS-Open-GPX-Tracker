//
//  ViewController.swift
//  OpenGpxTracker
//
//  Created by merlos on 13/09/14.
//  Copyright (c) 2014 TransitBox. All rights reserved.
//

import UIKit

import CoreLocation
import MapKit


//Accuracy levels
//  kBadSignalAccuracy would be greate than mediumSignal accuracy
let kMediumSignalAccuracy = 100.0
let kGoodSignalAccuracy = 20.0
let kPauseButtonBackgroundColor: UIColor =  UIColor(red: 146.0/255.0, green: 166.0/255.0, blue: 218.0/255.0, alpha: 0.90)
let kResumeButtonBackgroundColor: UIColor =  UIColor(red: 142.0/255.0, green: 224.0/255.0, blue: 102.0/255.0, alpha: 0.90)

let kStartButtonBackgroundColor: UIColor = UIColor(red: 142.0/255.0, green: 224.0/255.0, blue: 102.0/255.0, alpha: 0.90)
let kStopButtonBackgroundColor: UIColor =  UIColor(red: 244.0/255.0, green: 94.0/255.0, blue: 94.0/255.0, alpha: 0.90)

let kDeleteButtonTag = 10000

class ViewController: UIViewController, MKMapViewDelegate,CLLocationManagerDelegate, UIGestureRecognizerDelegate, UIAlertViewDelegate {
    
    //MapView and User vars
    let locationManager : CLLocationManager
    let map: MKMapView
    
    //Status Vars
    var followUser = true // MapView centered in user location
    
    var stopWatch = StopWatch()
    var timer = NSTimer()
    
    enum GpxTrackingStatus {
        case NotStarted
        case Tracking
        case Paused
        case Finished
    }
    var gpxTrackingStatus = GpxTrackingStatus.NotStarted
    var pinSeq = 1
    var trackSeq = 1

    var waypointPins : [GPXWaypoint] = []
    var gpxTrackSegments : [GPXTrackSegment] = []
    var gpxCurrentSegment: GPXTrackSegment
    var mapCurrentSegmentOverlay: MKPolyline //Polyline conforms MKOverlay protocol
    //UI
    //labels
    let appTitleLabel: UILabel
    let signalImageView: UIImageView
    let coordsLabel: UILabel
    let timeLabel : UILabel
    let trackedDistanceLabel : UILabel
    let segmentDistanceLabel : UILabel
    
    //buttons
    let followUserButton: UIButton
    let newPinButton: UIButton
    let folderButton: UIButton
    
    let startButton: UIButton
    let stopButton: UIButton
    var pauseButton: UIButton // Pause & Resume
    
    let badSignalImage = UIImage(named: "1")
    let midSignalImage = UIImage(named: "2")
    let goodSignalImage = UIImage(named: "3")
   
    

    // Initializer. Just initializes the class vars/const
    required init(coder aDecoder: NSCoder) {
        
        self.locationManager = CLLocationManager()
        self.map = MKMapView(coder: aDecoder)
        
        self.appTitleLabel = UILabel(coder: aDecoder)
        self.signalImageView = UIImageView(coder: aDecoder)
        self.coordsLabel = UILabel(coder: aDecoder)
        self.timeLabel = UILabel(coder: aDecoder)
        self.trackedDistanceLabel = UILabel(coder: aDecoder)
        self.segmentDistanceLabel = UILabel(coder: aDecoder)
        
        self.followUserButton = UIButton(coder: aDecoder)
        self.newPinButton = UIButton(coder: aDecoder)
        self.folderButton = UIButton(coder: aDecoder)
        self.startButton = UIButton(coder: aDecoder)
        self.stopButton = UIButton(coder: aDecoder)
        self.pauseButton = UIButton(coder: aDecoder)
        
        self.waypointPins = []
        self.gpxTrackSegments = []
        self.gpxCurrentSegment = GPXTrackSegment()
        var tmpCoords: [CLLocationCoordinate2D] = [] //init with empty
        self.mapCurrentSegmentOverlay = MKPolyline(coordinates: &tmpCoords, count: 0)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Location stuff
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
        
        
        // Map configuration Stuff
        map.delegate = self
        map.showsUserLocation = true
        let mapH: CGFloat = self.view.bounds.size.height - 64.0
        map.frame = CGRect(x: 0, y: 64.0, width: self.view.bounds.size.width, height: mapH)
        map.zoomEnabled = true
        map.rotateEnabled = true
        map.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: "addPinAtTappedLocation:")
        )
        let panGesture = UIPanGestureRecognizer(target: self, action: "stopFollowingUser:")
        panGesture.delegate = self
        map.addGestureRecognizer(panGesture)
        
        // set default zoon
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 8.90, longitude: -79.50), span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))
        map.setRegion(region, animated: true)
        
        self.view.addSubview(map)
        
        //add signal accuracy images.
        signalImageView.image = badSignalImage
        signalImageView.frame = CGRect(x: self.view.frame.width/2 - 25.0, y: 28, width: 50, height: 30)
        map.addSubview(signalImageView)
        
        // add FolderButton
        folderButton.frame = CGRect(x: 5, y: 25, width: 32, height: 32)
        folderButton.setImage(UIImage(named: "folder"), forState: UIControlState.Normal)
        folderButton.setImage(UIImage(named: "folderHigh"), forState: .Highlighted)
        folderButton.addTarget(self, action: "openFolderViewController", forControlEvents: .TouchUpInside)
        self.view.addSubview(folderButton)

        /*
        //add the app title Label (Branding, branding, branding! )
        let appTitleW: CGFloat = 200.0
        let appTitleH: CGFloat = 34.0
        let appTitleX: CGFloat = self.view.frame.width/2 - appTitleW/2
        let appTitleY: CGFloat = 30.0
        appTitleLabel.frame = CGRect(x:appTitleX, y: appTitleY, width: appTitleW, height: appTitleH)
        appTitleLabel.text = "Open GPX Tracker"
        appTitleLabel.textAlignment = .Center
        appTitleLabel.font = UIFont.boldSystemFontOfSize(20)
        //appTitleLabel.textColor = UIColor(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        appTitleLabel.textColor = UIColor(red: 7.0/255.0, green: 140.0/255.0, blue: 234.0/255.0, alpha: 1.0)
        self.view.addSubview(appTitleLabel)
        */
        
        //FollowUserButton
        followUserButton.frame = CGRect(x: 5, y: map.frame.height-37, width: 32, height: 32)
        followUserButton.setImage(UIImage(named: "followUserOn"), forState: UIControlState.Normal)
        followUserButton.setImage(UIImage(named: "followUserOff"), forState: .Highlighted)
        followUserButton.addTarget(self, action: "followButtonTroggler", forControlEvents: .TouchUpInside)
        map.addSubview(followUserButton)
        
        
        //tracking buttons
        //start
        let startW: CGFloat = 80.0
        let startH: CGFloat = 80.0
        let startX: CGFloat = self.map.frame.width/2 - startW/2 + 10
        let startY: CGFloat = self.map.frame.height - startH - 5
        startButton.frame = CGRect(x: startX, y:startY, width: startW, height: startH)
        startButton.setTitle("Start Tracking", forState: .Normal)
        startButton.backgroundColor = kStartButtonBackgroundColor
        startButton.addTarget(self, action: "startGpxTracking", forControlEvents: .TouchUpInside)
        startButton.hidden = false
        startButton.titleLabel?.font = UIFont.boldSystemFontOfSize(16)
        startButton.titleLabel?.numberOfLines = 2
        startButton.titleLabel?.textAlignment = .Center
        startButton.layer.cornerRadius = 40.0
        map.addSubview(startButton)
        
        //Stop
        let stopW: CGFloat = 70.0
        let stopH: CGFloat = 70.0
        let stopX: CGFloat = self.map.frame.width/2 + 15.0
        let stopY: CGFloat = self.map.frame.height - stopH - 5.0
        stopButton.frame = CGRect(x: stopX, y: stopY, width: stopW, height: stopH)
        stopButton.setTitle("Finish", forState: .Normal)
        stopButton.backgroundColor = kStopButtonBackgroundColor
        stopButton.addTarget(self, action: "stopGpxTracking", forControlEvents: .TouchUpInside)
        stopButton.hidden = true
        stopButton.titleLabel?.textAlignment = .Center
        stopButton.layer.cornerRadius = 35.0
        map.addSubview(stopButton)
        
        let pauseW: CGFloat = 70.0
        let pauseH: CGFloat = 70.0
        let pauseX: CGFloat = self.map.frame.width/2  - pauseW + 10.0
        let pauseY: CGFloat = self.map.frame.height - pauseH - 5.0
        pauseButton.frame = CGRect(x: pauseX, y: pauseY, width: pauseW, height: pauseH)
        pauseButton.backgroundColor = kPauseButtonBackgroundColor
        pauseButton.setTitle("Pause", forState: .Normal)
        pauseButton.addTarget(self, action: "pauseGpxTracking", forControlEvents: .TouchUpInside)
        pauseButton.hidden = true
        pauseButton.titleLabel?.textAlignment = .Center
        pauseButton.layer.cornerRadius = 35.0
        map.addSubview(pauseButton)
        
        //CoordLabel
        coordsLabel.frame = CGRect(x: self.map.frame.width/2 - 150, y: 2, width: 300, height: 20)
        coordsLabel.textAlignment = .Center
        coordsLabel.font = UIFont.systemFontOfSize(14)
        coordsLabel.text = "Not getting location"
        map.addSubview(coordsLabel)
        
        //timeLabel
        timeLabel.frame = CGRect(x: self.map.frame.width/2 - 150 + 12.5, y: map.frame.height -  startH - 25, width: 300, height: 20)
        timeLabel.textAlignment = .Center
        timeLabel.font = UIFont.boldSystemFontOfSize(14)
        timeLabel.text = "00:00:00"
        //timeLabel.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        map.addSubview(timeLabel)
        

        /*//pin button
        newPinButton.frame = CGRect(x: self.view.frame.width - 47, y: 25, width: 40, height: 40)
        newPinButton.setImage(UIImage(named: "addPin"), forState: UIControlState.Normal)
        newPinButton.setImage(UIImage(named: "addPinHigh"), forState: .Highlighted)
        newPinButton.addTarget(self, action: "addPinAtMyLocation", forControlEvents: .TouchUpInside)
        let newPinLongPress = UILongPressGestureRecognizer(target: self, action: "newPinLongPress:")
        newPinButton.addGestureRecognizer(newPinLongPress)
        self.view.addSubview(newPinButton)
        */
        
        
        
    }

    func openFolderViewController() {
        println("OpenFolderViewController")
        
        let vc = GPXFilesTableViewController(nibName: nil, bundle: nil)
        let navController = UINavigationController(rootViewController: vc)
        self.presentViewController(navController, animated: true) { () -> Void in
            
        }
    }
    
    func stopFollowingUser(gesture: UIPanGestureRecognizer) {
        println("Pan gesture detected: stop Following user")
        self.followUser = false
        followUserButton.setImage(UIImage(named: "followUserOff"), forState: .Normal)
    }
    
    // UIGestureRecognizerDelegate required for stopFollowingUser
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
   func addPinAtTappedLocation(gesture: UILongPressGestureRecognizer) {
    
        if  gesture.state == UIGestureRecognizerState.Began {
            println("Adding Pin map Long Press Gesture")
            let point: CGPoint = gesture.locationInView(self.map)
            let coords = self.map.convertPoint(point, toCoordinateFromView: self.map)
            let pin = GPXWaypoint(coordinate: coords)
            self.waypointPins.append(pin)
            map.addAnnotation(pin)
        }
    }
    
    func newPinLongPress(gesture: UILongPressGestureRecognizer) {
        if  gesture.state == UIGestureRecognizerState.Ended {
            println("Long Press");
        }
    }
    
    func addPinAtMyLocation() {
        println("Adding Pin at my location")
        let pin = GPXWaypoint(coordinate: map.userLocation.coordinate)
        self.waypointPins.append(pin)
        map.addAnnotation(pin)
        
    }
    
    
    func followButtonTroggler(){
        if self.followUser {
            self.followUser = false
            followUserButton.setImage(UIImage(named: "followUserOff"), forState: .Normal)
        } else {
            self.followUser = true
            followUserButton.setImage(UIImage(named: "followUserOn"), forState: .Normal)
           
        }
    }
    ////////////////////////////
    // TRACKING USER

    func pauseGpxTracking() {
        println("Paused/resumed GPX tracking")
        switch gpxTrackingStatus {
        case .Tracking:
            println("Paused GPX tracking")
            //update tracking status and add segment to track, new overlay
            self.gpxTrackingStatus = GpxTrackingStatus.Paused
            self.gpxTrackSegments.append(self.gpxCurrentSegment)
            self.gpxCurrentSegment = GPXTrackSegment()
            self.mapCurrentSegmentOverlay = MKPolyline()
            
            self.pauseButton.setTitle("Resume", forState: .Normal)
            self.pauseButton.backgroundColor = UIColor.greenColor()
            self.pauseButton.backgroundColor = kResumeButtonBackgroundColor
            
            self.stopWatch.stop()
            timer.invalidate()
            
        case .Paused:
            println("Resumed GPX tracking")
            self.gpxTrackingStatus = GpxTrackingStatus.Tracking
            
            //update UI
            self.pauseButton.setTitle("Pause", forState: .Normal)
            
            //restart timer
            self.stopWatch.start()
            timer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: "updateTime", userInfo: nil, repeats: true)
            self.pauseButton.backgroundColor = kPauseButtonBackgroundColor
            
            
        default:
            println("ERROR: Yeeeeeee! pauseGpxTracking shall never be called with \(gpxTrackingStatus)")
        }
    
    }
    
    func startGpxTracking() {
        println("startGpxTracking::")
        switch gpxTrackingStatus {
        case .NotStarted:
            println("Not Started => initializing")
        case .Finished:
            println("Finish => RE initializing")
        default:
            println("ERROR: startGpxTracking")
        }
        
        if !timer.valid {
            timer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: "updateTime", userInfo: nil, repeats: true)
            self.stopWatch.reset()
            self.stopWatch.start()
        }
        
        gpxTrackingStatus = .Tracking
        
        UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
            self.startButton.hidden = true
            self.stopButton.hidden = false
            self.pauseButton.hidden = false
            }, completion: {(f: Bool) -> Void in
                println("finished animation start tracking")
            })
        
    }
    
    
    func stopGpxTracking() {
        println("stop GPX Tracking called")
        
        let alert = UIAlertView(title: "Save as", message: "Enter GPX session name", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Save")
        alert.alertViewStyle = .PlainTextInput;
        
        //set default file name
        let dateFormat = NSDateFormatter()
        let now = NSDate()
        dateFormat.setLocalizedDateFormatFromTemplate("YYYY-MMM-dd HH:mm:ss")
        alert.textFieldAtIndex(0)?.text = dateFormat.stringFromDate(now)
        alert.show();
    }
    
    
    //UIAlertView Delegate
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        println("alertViewDelegate clickedButton || this alertview delegate if for saving files")
        switch buttonIndex {
        case 0: //cancel
            println("Finish canceled")
        case 1:
            //get name of the file to save
            let filename = alertView.textFieldAtIndex(0)?.text
            println("Save File \(filename)")
            
            //hide stop and pause, and show start tracking
            gpxTrackingStatus = .Finished
            self.startButton.hidden = false
            self.stopButton.hidden = true
            self.pauseButton.hidden = true
            
            self.pauseButton.setTitle("Pause", forState: .Normal)
            self.pauseButton.backgroundColor = kPauseButtonBackgroundColor
            
            //Stop Timer
            stopWatch.stop()
            timer.invalidate()
            
            self.gpxTrackSegments.append(self.gpxCurrentSegment)
            self.gpxCurrentSegment = GPXTrackSegment()
            self.mapCurrentSegmentOverlay = MKPolyline()
            
            //Create the gpx file
            let gpx = GPXRoot(creator: "Open GPX Tracker for iOS")
            gpx.addWaypoints(waypointPins)
            let track = GPXTrack()
            track.addTracksegments(gpxTrackSegments)
            gpx.addTrack(track)
            
            //save it
            GPXFileManager.save(filename!, gpxContents: gpx.gpx())
            //clear tracks, pins and overlays
            self.gpxTrackSegments = []
            self.gpxCurrentSegment = GPXTrackSegment()
            self.waypointPins = []
            self.map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations)
            //println(gpx.gpx())
            
            
        default:
            println("[ERROR] it seems there are more than two buttons on the alertview.")
        }
    }
    
    
    // location Delegate
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
         println("didFailWithError\(error)");
        
        // var alert : UIAlertView  = UIAlertView(title: "Ouch!", message: "Cannot get your location!", delegate: self, cancelButtonTitle: "Understod")
        //alert.show()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateToLocation newLocation: CLLocation!, fromLocation oldLocation: CLLocation!) {
        //println("didUpdateToLocation \(newLocation.coordinate.latitude),\(newLocation.coordinate.longitude), Hacc: \(newLocation.horizontalAccuracy), Vacc: \(newLocation.verticalAccuracy)")
      
        if (newLocation.horizontalAccuracy < kMediumSignalAccuracy) {
            self.signalImageView.image = midSignalImage;
        } else {
            self.signalImageView.image = badSignalImage;
        }
        if (newLocation.horizontalAccuracy < kGoodSignalAccuracy) {
            self.signalImageView.image = goodSignalImage;
        }
        
        coordsLabel.text = "(\(newLocation.coordinate.latitude),\(newLocation.coordinate.longitude))"
        if followUser {
            //map.centerCoordinate = newLocation.coordinate
            let region = MKCoordinateRegion(center: newLocation.coordinate, span: map.region.span)
            map.setRegion(region, animated: true)
        }
        if gpxTrackingStatus == .Tracking {
            println("didUpdateLocation: adding point to track")
            let pt = GPXTrackPoint(location: newLocation)
            gpxCurrentSegment.addTrackpoint(pt)
            //redrawCurrent track segment overlay
            //First remove last overlay, then re-add the overlay updated with the new point
            map.removeOverlay(mapCurrentSegmentOverlay)
            mapCurrentSegmentOverlay = gpxCurrentSegment.overlay
            map.addOverlay(mapCurrentSegmentOverlay)
        }
        
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation.isKindOfClass(MKUserLocation)) { return nil }
          let annotationView : MKPinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "PinView")
        annotationView.canShowCallout = true
        let detailButton : UIButton = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as UIButton
        detailButton.tag = kDeleteButtonTag
        annotationView.draggable = true
        //detailButton.addTarget(self, action: "deleteAnnotation:", forControlEvents: .TouchUpInside)
        annotationView.rightCalloutAccessoryView = detailButton
        return annotationView;
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            var pr = MKPolylineRenderer(overlay: overlay);
            pr.strokeColor = UIColor.blueColor().colorWithAlphaComponent(0.5);
            pr.lineWidth = 3;
            return pr;
        }
        return nil
    }
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        let button = control as UIButton
        if (button.tag == kDeleteButtonTag) {
            println("DELETEEEEERRRR")
        }
        
        println("Toma! Toma! \(view.annotation.title)")
        let point = view.annotation as GPXWaypoint
        let index = find(waypointPins, point)
        if index != nil {
            println("[DELETE] found annotation, deleting it");
            waypointPins.removeAtIndex(index!)
            mapView.removeAnnotation(view.annotation!)
        }
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if (newState == MKAnnotationViewDragState.Ending){
            let point = view.annotation as GPXWaypoint
            println("Annotation name: \(point.title) lat:\(point.latitude) lon \(point.longitude)")
        }
    }
    
    
    
    func mapView(mapView: MKMapView!, didAddAnnotationViews views: [AnyObject]!) {
        var i = 0
        for object in views {
            i++
            let aV = object as MKAnnotationView
            if aV.annotation.isKindOfClass(MKUserLocation) { continue }
            
            let point : MKMapPoint = MKMapPointForCoordinate(aV.annotation.coordinate)
            if !MKMapRectContainsPoint(self.map.visibleMapRect, point) { continue }
         
            let endFrame: CGRect = aV.frame
            aV.frame = CGRect(x: aV.frame.origin.x, y: aV.frame.origin.y - self.view.frame.size.height, width: aV.frame.size.width, height:aV.frame.size.height)
            let interval : NSTimeInterval = 0.04 * 1.1
            UIView.animateWithDuration(0.5, delay: interval, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                aV.frame = endFrame
                }, completion: { (finished) -> Void in
                    if finished {
                        UIView.animateWithDuration(0.05, animations: { () -> Void in
                            //aV.transform = CGAffineTransformMakeScale(1.0, 0.8);
                            aV.transform = CGAffineTransform(a: 1.0, b: 0, c: 0, d: 0.8, tx: 0, ty: aV.frame.size.height*0.1)
                            
                            }, completion: { (finished: Bool) -> Void in
                            UIView.animateWithDuration(0.1, animations: { () -> Void in
                                aV.transform = CGAffineTransformIdentity
                                })
                        })
                    }
            })
        }
    }
    
    
    
    func updateTime() {
        //concatenate minuets, seconds and milliseconds as assign it to the UILabel
        timeLabel.text = stopWatch.elapsedTimeString
    }
    

 
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
