function [ obj ] = setupSystemObject( VidName )

obj.reader = vision.VideoFileReader(VidName);
        obj.videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
        obj.maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
        obj.detector = vision.ForegroundDetector('NumGaussians', 3, ...
            'NumTrainingFrames', 1495, 'MinimumBackgroundRatio', 0.7);
            
        obj.blobAnalyser = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
            'AreaOutputPort', true, 'CentroidOutputPort', true, ...
            'MinimumBlobArea', 400);

end

