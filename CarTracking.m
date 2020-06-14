function [ nextId ] = CarTracking( VidName )
vidObj = VideoReader(VidName);
numFrames = ceil(vidObj.FrameRate*vidObj.Duration);

obj = setupSystemObjects();

checkerObj = setupSystemObjects();

tracks = initializeTracks();

nextId = 1; % ID of the next track

% Detect moving objects, and track them across video frames.
while ~isDone(obj.reader)
    frame = readFrame();
    % to check for objects if real or noise 
%     checkerframe = checkerObj.reader.step();
%     MaskOfChecker = checkerObj.detector.step(frame);
    
    
    [centroids, bboxes, mask] = detectObjects(frame);
    predictNewLocationsOfTracks();
    [assignments, unassignedTracks, unassignedDetections] = ...
        detectionToTrackAssignment();
    
    updateAssignedTracks();
    updateUnassignedTracks();
    deleteLostTracks();
    createNewTracks();
    
    displayTrackingResults();
end


    function obj = setupSystemObjects()
        
        obj.reader = vision.VideoFileReader(VidName);
        obj.videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
        obj.maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
        obj.detector = vision.ForegroundDetector('NumGaussians', 3, ...
            'NumTrainingFrames', numFrames, 'MinimumBackgroundRatio', 0.7);
            
        obj.blobAnalyser = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
            'AreaOutputPort', true, 'CentroidOutputPort', true, ...
            'MinimumBlobArea', 400);
    end
%%% TRACKS Function 
  function tracks = initializeTracks()
        % create an empty array of tracks
        tracks = struct(...
            'id', {}, ...
            'bbox', {}, ...
            'kalmanFilter', {}, ...
            'age', {}, ...
            'totalVisibleCount', {}, ...
            'consecutiveInvisibleCount', {} ,'TotalPixelsMoved',{} , 'Centroid' , {} ,...
            'speed',{},'PC',{},'NC',{} ,'lines',{} ,'Degree',{} ,...
             'area',{} ,'ratio',{} , 'ir',{});
  end

  function frame = readFrame()
        frame = obj.reader.step();
  end
 function [centroids, bboxes, mask] = detectObjects(frame)
        
        % Detect foreground.
        mask = obj.detector.step(frame);
        
        % Apply morphological operations to remove noise and fill in holes.
        mask = imopen(mask, strel('rectangle', [3,3]));
        mask = imclose(mask, strel('rectangle', [15, 15])); 
        mask = imfill(mask, 'holes');
       
        % Perform blob analysis to find connected components.
        [~, centroids, bboxes] = obj.blobAnalyser.step(mask);
        
        
 end

%%%%%%%%%%% predict new locarion 
 function predictNewLocationsOfTracks()
        for i = 1:length(tracks)
            bbox = tracks(i).bbox;
            
            % Predict the current location of the track.
            predictedCentroid = predict(tracks(i).kalmanFilter);
            
            % Shift the bounding box so that its center is at 
            % the predicted location.
            predictedCentroid = int32(predictedCentroid) - bbox(3:4) / 2;
            tracks(i).bbox = [predictedCentroid, bbox(3:4)];
        end
 end
function [assignments, unassignedTracks, unassignedDetections] = ...
            detectionToTrackAssignment()
        
        nTracks = length(tracks);
        nDetections = size(centroids, 1);
        
        % Compute the cost of assigning each detection to each track.
        cost = zeros(nTracks, nDetections);
        for i = 1:nTracks
            cost(i, :) = distance(tracks(i).kalmanFilter, centroids);
        end
         
        % Solve the assignment problem.
        costOfNonAssignment = 20;
        [assignments, unassignedTracks, unassignedDetections] = ...
            assignDetectionsToTracks(cost, costOfNonAssignment);
end
 function updateAssignedTracks()
        numAssignedTracks = size(assignments, 1);
        for i = 1:numAssignedTracks
            trackIdx = assignments(i, 1);
            detectionIdx = assignments(i, 2);
            centroid = centroids(detectionIdx, :);
            bbox = bboxes(detectionIdx, :);
            
           distance = sqrt(((centroid(1,1)-tracks(trackIdx).Centroid(1,1))^2+(centroid(1,2)-tracks(trackIdx).Centroid(1,2))^2));
            % Correct the estimate of the object's location
            % using the new detection.
            correct(tracks(trackIdx).kalmanFilter, centroid);
             tracks(trackIdx).ir = (bbox(1,4)/bbox(1,3)*1000 )-(tracks(trackIdx).bbox(1,4)/tracks(trackIdx).bbox(1,3)*100 );
             if (tracks(trackIdx).ir > 1800)
                 tracks(trackIdx).ratio =tracks(trackIdx).ratio * 10;
             end 
            % Replace predicted bounding box with detected
            % bounding box.
            tracks(trackIdx).bbox = bbox;
            %update Area 
            tracks(trackIdx).area = bbox(1,3)*bbox(1,4);
            % Update track's age.
            tracks(trackIdx).age = tracks(trackIdx).age + 1;
            %update totalpixelsMoved 
            
            tracks(trackIdx).lines(tracks(trackIdx).NC,:)=[tracks(trackIdx).PC centroid];
            tracks(trackIdx).NC = tracks(trackIdx).NC + 1;   
            p1 = GetPointFcenter(frame,tracks(trackIdx).PC);
            p2 = GetPointFcenter(frame,centroid);
            Deg = atan ( (p2(1,2) -  p1(1,2))/ (p2(1,1)-p1(1,1)));
            Deg = Deg * 100;
            if (Deg  < 0 )
                Deg = -1 * Deg ; 
                Deg = Deg + 90 ;
            end
            tracks(trackIdx).Degree = Deg ;
            tracks(trackIdx).TotalPixelsMoved =  tracks(trackIdx).TotalPixelsMoved + distance;
            
            %update Centroid 
            tracks(trackIdx).PC = tracks(trackIdx).Centroid;
            tracks(trackIdx).Centroid = centroid;
            % Update visibility.
            tracks(trackIdx).totalVisibleCount = ...
                tracks(trackIdx).totalVisibleCount + 1;
            tracks(trackIdx).consecutiveInvisibleCount = 0;
            %update speed 
            tracks(trackIdx).speed=tracks(trackIdx).TotalPixelsMoved/tracks(trackIdx).totalVisibleCount;
            %update ratio 
            tracks(trackIdx).ratio =  tracks(trackIdx).ratio +((((bbox(1,4)/bbox(1,3)))*100)/tracks(trackIdx).age);
            disp(tracks(trackIdx).ratio);
        end
 end
function updateUnassignedTracks()
        for i = 1:length(unassignedTracks)
            ind = unassignedTracks(i);
            tracks(ind).age = tracks(ind).age + 1;
            tracks(ind).consecutiveInvisibleCount = ...
                tracks(ind).consecutiveInvisibleCount + 1;
        end
end
    function deleteLostTracks()
        if isempty(tracks)
            return;
        end
        
        invisibleForTooLong = 15;
        ageThreshold = 8;
        
        % Compute the fraction of the track's age for which it was visible.
        ages = [tracks(:).age];
        totalVisibleCounts = [tracks(:).totalVisibleCount];
        visibility = totalVisibleCounts ./ ages;
        
        % Find the indices of 'lost' tracks.
        lostInds = (ages < ageThreshold & visibility < 0.6) | ...
            [tracks(:).consecutiveInvisibleCount] >= invisibleForTooLong;
        
        % Delete lost tracks.
        tracks = tracks(~lostInds);
    end
 function createNewTracks()
        centroids = centroids(unassignedDetections, :);
        bboxes = bboxes(unassignedDetections, :);
        
        for i = 1:size(centroids, 1)
            
            centroid = centroids(i,:);
            bbox = bboxes(i, :);
            
            % Create a Kalman filter object.
            kalmanFilter = configureKalmanFilter('ConstantVelocity', ...
                centroid, [200, 50], [100, 25], 100);
            
            % Create a new track.
            newTrack = struct(...
                'id', nextId, ...
                'bbox', bbox, ...
                'kalmanFilter', kalmanFilter, ...
                'age', 1, ...
                'totalVisibleCount', 1, ...
                'consecutiveInvisibleCount', 0 , 'TotalPixelsMoved',0 ,'Centroid',centroid , 'speed' ,0 ,'PC' ,centroid ,'NC' , 1 ,...
                'lines',zeros(1,4),'Degree',0,'area',bbox(1,3)*bbox(1*4),'ratio',bbox(1,3)/bbox(1*4) , 'ir',0);
            
            % Add it to the array of tracks.
            tracks(end + 1) = newTrack;
            
            % Increment the next id.
            nextId = nextId + 1;
        end
 end
 function displayTrackingResults()
        % Convert the frame and the mask to uint8 RGB.
        frame = im2uint8(frame);
        mask = uint8(repmat(mask, [1, 1, 3])) .* 255;
        
        minVisibleCount = 6;
        if ~isempty(tracks)
              
            % Noisy detections tend to result in short-lived tracks.
            % Only display tracks that have been visible for more than 
            % a minimum number of frames.
            reliableTrackInds = ...
                [tracks(:).totalVisibleCount] > minVisibleCount;
            reliableTracks = tracks(reliableTrackInds);
            
            % Display the objects. If an object has not been detected
            % in this frame, display its predicted bounding box.
            if ~isempty(reliableTracks)
                % Get bounding boxes.
                bboxes = cat(1, reliableTracks.bbox);
               
%                 CDZ = cat(1, reliableTracks.Centroid);
%                 PDZ = cat(1, reliableTracks.PC);
%                 for d = 1:length(CDZ)
%                     lines = GetLines(CDZ(d),PDZ(d));
%                     frame = insertShape(frame , 'Line' , lines);
%                 end
%                 lines = [CDZ PDZ];
             
                % Get ids.
                ids = int32([reliableTracks(:).id]);
                distance=int32([reliableTracks(:).TotalPixelsMoved]);
                speed=int32([reliableTracks(:).speed]);
                Degrees=int32([reliableTracks(:).Degree]);
                labelz = cellstr(int2str(Degrees'));
                ratios =([reliableTracks(:).ratio]);
                ir =([reliableTracks(:).ir]);
                ir=cellstr(num2str(ir'));
                ratios2 = cellstr(num2str(ratios'));
                %actualWhite = WhiteInThere()
                
               numbers = WhiteInThere(bboxes , mask);
               for i = 1 : length(numbers)
                   if (numbers(i) < 800 )
                       bboxes(i,3)=0;
                       bboxes(i,4)=0;
                       bboxes(i,1)=0;
                       bboxes(i,2)=0;
                   end
                   %uncomment this to block humans 
                   if (ratios(i)>650)
                       bboxes(i,3)=0;
                       bboxes(i,4)=0;
                       bboxes(i,1)=0;
                       bboxes(i,2)=0;
                   end
                       
               end
                lines = cat(1, reliableTracks.lines); 
                % Create labels for objects indicating the ones for 
                % which we display the predicted rather than the actual 
                % location.
                labels = cellstr(int2str(speed'));
               
                labels =strcat({'speed = '},labels,{', degree = '} , labelz );
                predictedTrackInds = ...
                    [reliableTracks(:).consecutiveInvisibleCount] > 5;
                xyz = predictedTrackInds;
                isPredicted = cell(size(labels));
                isPredicted(predictedTrackInds) = {' predicted'};
                labels = strcat(labels, isPredicted);
                
                % Draw the objects on the frame.
               frame = insertShape(frame , 'Line' , lines ,'Color','red');
               frame = insertObjectAnnotation(frame, 'rectangle', ...
                    bboxes, labels ,'color','red' ,'FontSize' , 17);
                
                % Draw the objects on the mask.
                mask = insertObjectAnnotation(mask, 'rectangle', ...
                    bboxes, labels ,'color','red');
            end
        end
        
        % Display the mask and the frame.
         
        
         %obj.maskPlayer.step(mask);  
        
         obj.videoPlayer.step(frame);
         
%         checkerObj.maskPlayer.step(MaskOfChecker); 
        
    end

end

