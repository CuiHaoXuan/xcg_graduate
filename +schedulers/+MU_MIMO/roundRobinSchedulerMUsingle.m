classdef roundRobinSchedulerMUsingle < schedulers.MU_MIMO.lteSchedulerMU
%This is the round Robin Scheduler, adapted for the MU-MIMO RB matrix. No
%actual multi-user scheduling is performed. There are several possibilities
% to schedule the RB grid. This scheduler is meant as a sanity check
% method.
% 

   properties
       % Where the scheduler will store which users to serve first (round robin fashion)
       UE_queue
       last_extracted
       length
       
       % See the lteScheduler class for a list of inherited attributes
   end

   methods
       
       % Class constructor. UE_queue size needs to be specified large
       % enough so it won't overflow
       function obj = roundRobinSchedulerMUsingle(scheduler_params,attached_eNodeB_sector)
           % Fill in basic parameters (handled by the superclass constructor)
           obj      = obj@schedulers.MU_MIMO.lteSchedulerMU(scheduler_params,attached_eNodeB_sector);
           obj.name = 'Round Robin scheduler MU single';
       end
       
       % Add a UE to the queue. It could be done so each TTI the scheduler
       % gets a UE list from the eNodeB, but such a query is not necessary.
       % Just updating when a UE attaches or drops is sufficient.
       function add_UE(obj,UE_id)
           % If not in queue: add
           if ~sum(obj.UE_queue==UE_id)
               if isempty(obj.UE_queue)
                   obj.last_extracted = 1;
               end
               obj.UE_queue = [obj.UE_queue UE_id];
               obj.length   = length(obj.UE_queue);
           end
       end
       
       % Delete an UE_id from the queue
       function remove_UE(obj,UE_id)
           % Remove the UE with this UE_id
           removed_set  = obj.UE_queue~=UE_id;
           obj.UE_queue = obj.UE_queue(removed_set);
           obj.length   = length(obj.UE_queue);
           
           % Adjust the last_extracted variable
           if ~isempty(find(removed_set,1))
               if obj.last_extracted>=find(removed_set,1)
                   obj.last_extracted = mod(obj.last_extracted-2,obj.length)+1; % One-indexed modulo-length adding of one
               end
           end
           
           if obj.length==0
               obj.last_extracted = [];
           end
       end
       
       % Next user to serve. If the queue is empty, returns 0
       function UE_id = get_next_users(obj,number)
           % Return the first item and shift the whole thing one position
           to_extract         = mod(obj.last_extracted:(obj.last_extracted+number-1),obj.length)+1;
           UE_id              = obj.UE_queue(to_extract);
           obj.last_extracted = to_extract(end);
       end
       
       % Schedule the users in the given RB grid
       function schedule_users(obj,attached_UEs,last_received_feedbacks)
           % Power allocation
           % Nothing here. Leave the default one (homogeneous)
           
           % For now use the static tx_mode assignment
           RB_grid = obj.RB_grid;
           RB_grid.size_bits = 0;
           tx_mode           = obj.default_tx_mode;
           current_TTI       = obj.clock.current_TTI; 
           
           if ~isempty(attached_UEs)
               % Assign RBs to UEs, RR fashion
               type = 2;
               switch type
                   case 1
                       ind = kron([1 0], ones(size(RB_grid.user_allocation,1), 1));
                   case 2
                       ind = kron([0 1], ones(size(RB_grid.user_allocation,1), 1));
                   case 3
                        ind = 1:size(RB_grid.user_allocation,1);
                       ind = logical(ind+size(RB_grid.user_allocation,1)*mod(ind, 2));
                   otherwise
                       error('not supported')
               end

               ind = logical(ind);
               RB_grid.user_allocation(ind) = obj.get_next_users(size(RB_grid.user_allocation,1));
            
               
               % CQI assignment. TODO: implement HARQ
               obj.schedule_users_common(attached_UEs,last_received_feedbacks,current_TTI,tx_mode);
           end
       end
   end
end
