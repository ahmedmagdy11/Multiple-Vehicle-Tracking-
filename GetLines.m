function [lines ] = GetLines( centroid , prevCentroids )

[w,~] = size(prevCentroids);
lines = zeros (w , 4);
for i = 1:w 
    if (i+1 <= w )
        lines(i,:) = [ prevCentroids(i,:) prevCentroids(i+1,:)];
    end
end

% lines(w,:)= [ prevCentroids(w,:) centroid ];
end

