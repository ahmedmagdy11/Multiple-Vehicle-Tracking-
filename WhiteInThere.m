function [ numbers ] = WhiteInThere(bboxes , frame )
[sizeOFbb , ~ ] = size(bboxes);
numbers = zeros (sizeOFbb);
frame = im2bw(frame);

[w,h]= size(frame);

for k = 1:sizeOFbb 
y = bboxes (k,1);
x = bboxes (k,2);
y2 = y + bboxes(k,3);
x2 = x + bboxes(k,4);
for i=1:w
    for j=1:h
        if (i > x && j > y && i < x2 && j < y2 && frame(i,j)==1)
            numbers(k)= numbers(k) + 1;
        end
    end
end
end



end

