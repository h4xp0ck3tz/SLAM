classdef GRAPH_SLAM < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        x;            % state vector, holds all poses and landmarks
                      % The first half of the statevector will contain the
                      % poses and the second half will contain the
                      % landmarks. Poses have three variables: x,y,theta.
                      % Landmarks have two variables: x,y. New poses and
                      % landmarkes are appened to the end of their
                      % respective lists
                                  
        numLandmarks; % used to index through state vector
        numPoses;     % used to index through state vector
        
     %  u;           % control vector, used to store all previous control inputs. The 
                     % furthe down the list the more recent the control.
      
        mu;          % pose vector generated by the control vector during the
                     % initalization stage. Will also hold the landmarks on
                     % the map after the poses. The poses will be of the
                     % form x,y,z and the landmarks will be x,y,sig

        omega;  % information matrix
        xi;     % information vector
        
        
        
        Q=[.1 0 0;
            0 .1 0;
            0 0 .1;];
       
        % GRAPH_SLAM Parameter Values
        C = 0.2;    % Process Noise Constant, used for calcluation of Q.
        Rc = [.01,5];   % Measurement Noise Constants
        
        R=[.1,0,0;0,.1,0;0,0,.1];
    end
    
    methods
        % Constructor - initialize state variables and covariances
        function h = GRAPH_SLAM()
            h.mu=[0;0;0];
        end
        
        function runSlam(h,u,z,c)

            %determine number of poses and number of measurments and create
            %an information matrix and vector of the appropriate size
            h.numPoses=(length(u)/2)+1;
            h.numLandmarks=max([c{:}]);
            
            h.omega=zeros((h.numPoses*3+h.numLandmarks*3));
            h.xi=zeros(h.numPoses*3+h.numLandmarks*3,1);
            
            
            h.initalize(u,c);
            
            
            
            %linearize
            h.linearize(u,z,c);
        end
        
        function initalize(h,u,c)
            % Use all control vectors to calculate an mean estimate of the
            % pose. c is only used to extract landmarks from ransac
            
            %The inital position is always x=0,y=0,theta=0
            
            %Each control will contain two elements, the change in distance
            %and the change in theta (delta_D, delta_theta). The total
            %number of controls will be equal to the size of the control
            %vector divided by two. 
            for idx = 1: length(u)/2
                
                %Index for keeping track of the current pose being
                %calculated
                poseIdx=(3*idx)+1;
                
                %Index for keeping track of the previous pose
                previousPoseIdx=3*(idx-1)+1; 
                
                %Index for keeping track of the index of the control vector
                controlVecIdx=2*(idx-1)+1;
                
                %Calculate pose x,y, and theta based on previous pose and
                %control vector
                h.mu(poseIdx)= h.mu(previousPoseIdx) + u(controlVecIdx)*cosd(h.mu(previousPoseIdx+2)+u(controlVecIdx+1));
                h.mu(poseIdx+1)= h.mu(previousPoseIdx+1) + u(controlVecIdx)*sind(h.mu(previousPoseIdx+2)+u(controlVecIdx+1));
                h.mu(poseIdx+2)= h.mu(previousPoseIdx+2)+u(controlVecIdx+1);
                
            end
            
            %add intal landmark map positions to mu. 
            
            %ADD CODE TO EXTRACT LIST OF LANDMARKS FROM HERE
            landmarkIdxs=unique(cell2mat(c),'first');
            
            for idx=1:length(landmarkIdxs)
               
                %FIX THIS BY FILLING IN CORRECT NAMES
%                 landmark=landmarkObj.findLandmark(idx);
%                 h.mu(h.numPoses*3+(2*(1-idx))+1)=landmark(1);
%                 h.mu(h.numPoses*3+(2*(1-idx))+2)=landmark(2);
%                 h.mu(h.numPoses*3+(2*(1-idx))+3)=idx;
                  h.mu((h.numPoses*3)+(3*(idx-1))+1)=10;
                  h.mu((h.numPoses*3)+(3*(idx-1))+2)=10;
                  h.mu((h.numPoses*3)+(3*(idx-1))+3)=1;
            end
            
            
            
        end
        
        
        
        %Function to create the information matrix and information vector.
        
        %The control vector u will be a vector of the form,
        %distance1,theta1,distance2,theta2,...,distancen,thetan.
        
        %The measurment cell array z will be an nxm cell array where n is
        %the number of poses (a measurment is taken during every pose)
        %and m is the number of features observed in a measurment
        %If no feature is observed in a measurment then that cell in the
        %cell array fill be blank
        
        %The mean pose estimation mu will be vector of the form
        %x1,y1,theta1,x2,y2,theta2,...,xn,yn,thetan. Followed by the mean
        %landmark estimation of the form x1,y1,s1,x2,y2,s2,...,xn,yn,sn
        
        %note to self j will be the index of the landmark plus the size of
        %the number of poses. 
        function linearize(h,u,z,c) 
            
            h.omega(1:3,1:3)=[inf,0,0;0,inf,0;0,0,inf];
            
            %Add all poses to the information matrix
            %idx also represents the current time iteration,ie t=1,2,...,N,
            %not including t=0;
            %consider changing name of measurmentIDX
            for measurmentIdx = 1: length(u)/2

                %Index for keeping track of the previous pose from mu
                previousPoseIdx=3*(measurmentIdx-1)+1;
                
                %Index for keeping tack of the current control input
                controlVecIdx=2*(measurmentIdx-1)+1;
                
                x_t=[0;0;0];
                x_t(1)= h.mu(previousPoseIdx) + u(controlVecIdx)*cosd(h.mu(previousPoseIdx+2)+u(controlVecIdx+1));
                x_t(2)= h.mu(previousPoseIdx+1) + u(controlVecIdx)*sind(h.mu(previousPoseIdx+2)+u(controlVecIdx+1));
                x_t(3)= h.mu(previousPoseIdx+2) + u(controlVecIdx+1);
                
                G = eye(3);
                G(1,3) = -1*u(controlVecIdx)*sind(h.mu(previousPoseIdx+2));
                G(2,3) = u(controlVecIdx)*cosd(h.mu(previousPoseIdx+2));
                
                
                
                currentInfoStart=(3*(measurmentIdx-1))+1;
                
                %add to omega at xt and x_t-1
                a=[-G';eye(3)]*h.R^-1*[G,eye(3)];
                h.omega(currentInfoStart:currentInfoStart+5,currentInfoStart:currentInfoStart+5)...
                    =a+h.omega(currentInfoStart:currentInfoStart+5,currentInfoStart:currentInfoStart+5); 
                
                %add to xi
                b=[-G;eye(3)]*h.R^-1*[x_t-G*h.mu(previousPoseIdx:previousPoseIdx+2)];
                h.xi(currentInfoStart:currentInfoStart+5)=...
                    b+ h.xi(currentInfoStart:currentInfoStart+5); 
                
            end
            
            

            for measurmentIdx=1:length(z)
                %Check if this index of the measurment cell array contains
                %any measurments
                if (isempty(z{measurmentIdx})==0)
                    %for all measurments at this index of the measurment
                    %cell array
                    for observationIdx=1:size(z{measurmentIdx},1)
                        
                        %j is the index in mu which holds the current
                        %estimate of landmark cs' x position, the y
                        %position is j+1
                        j=((c{measurmentIdx}(observationIdx)-1)*3) + h.numPoses*3 +1;

                        %poseIdx is used to find the start of each pose
                        %within the mu vector
                        poseIdx=1+((measurmentIdx-1)*3);
                        
                        delta=[h.mu(j)-h.mu(poseIdx);h.mu(j+1)-h.mu(poseIdx+1)];
                        q=delta'*delta;
                        
                        %IMPORTANT: Double check atan2 calculation
                        z_hat=[sqrt(q);atan2d(delta(2),wrapTo360(angdiff(h.mu(poseIdx+2),delta(1))));h.mu(j+2)];
                        
                        H=1/q*[-sqrt(q)*delta(1), -sqrt(q)*delta(2), 0, sqrt(q)*delta(1), sqrt(q)*delta(2), 0;
                                   delta(2),          -delta(1),   -q,     -delta(2),        delta(1),     0;
                                      0,                   0,       0,         0,               0,         q];
                        
                                  
                        currentInfoPos=(3*(measurmentIdx-1))+1;
                        currentInfoLM=(3*h.numPoses)+1+((c{measurmentIdx}(observationIdx)-1)*3);
                        
                        
                        a= H'*h.Q^-1*H;
                        %add to omega at xt and mj
                        
                        %add 1:3,1:3
                        h.omega(currentInfoPos:currentInfoPos+2,currentInfoPos:currentInfoPos+2)...
                            =a(1:3,1:3)+h.omega(currentInfoPos:currentInfoPos+2,currentInfoPos:currentInfoPos+2);
                        
                        %add 4:6,4:6
                        h.omega(currentInfoLM:currentInfoLM+2,currentInfoLM:currentInfoLM+2)=...
                            a(4:6,4:6)+h.omega(currentInfoLM:currentInfoLM+2,currentInfoLM:currentInfoLM+2);
                        
                        %add 1:3,4:6
                        h.omega(currentInfoPos:currentInfoPos+2,currentInfoLM:currentInfoLM+2)...
                            =a(1:3,4:6)+h.omega(currentInfoPos:currentInfoPos+2,currentInfoLM:currentInfoLM+2);
                        
                        %add 4:6,1:3
                        h.omega(currentInfoLM:currentInfoLM+2,currentInfoPos:currentInfoPos+2)...
                            =a(4:6,1:3)+h.omega(currentInfoLM:currentInfoLM+2,currentInfoPos:currentInfoPos+2);
                        

                        b=H'*h.Q^-1*[z{measurmentIdx}(observationIdx)-z_hat+H*[h.mu(poseIdx);h.mu(poseIdx+1);h.mu(poseIdx+2);h.mu(j);h.mu(j+1);h.mu(j+2)]];
                        %add to xi at xt and mj
                        
                        h.xi(currentInfoPos:currentInfoPos+2)...
                            =b(1:3)+h.xi(currentInfoPos:currentInfoPos+2);
                        
                        h.xi(currentInfoLM:currentInfoLM+2)...
                            =b(4:6)+h.xi(currentInfoLM:currentInfoLM+2);
                    end
                    
                end
                
            end
            
        end
        
        
        %This function follows the algorith GraphSLAM_reduce on page 349 of
        %the book. The information matrix omega and information vector xi
        %are used for this function.
        function reduce(h)
            
            
        end
        
    end
    
end