function [ newpoint ] = GetPointFcenter( img , point )

[w , h ,~]= size (img);
newpoint(1,1) = point(1,1) - (w/2)+1;
newpoint(1,2)= (h/2 )+ 1 - point(1,2);
end

