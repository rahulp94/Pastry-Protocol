defmodule Project3 do
  #use GenServer

  def main(args) do
    args |> parse_args
  end

  def parse_args([]) do
    IO.puts "No parameters entered"
  end

  def parse_args(args) do
    {_, [numNodes,numRequests], _} = OptionParser.parse(args)
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    all = numNodes*numRequests
    Process.register(self(), :main)
    process_list = createNodesandActors(numNodes,numRequests)
    #IO.inspect process_list
    #processMsgRequest(process_list,numRequests)
    findNewDest(process_list,numRequests)

    allHops = incrementHopCounter(0,0,all)
    #allHops = 100
    #allHops = addHops(tot)
    avgHops = allHops/all
    IO.puts(avgHops)
  end

  def incrementHopCounter(total,i,cnt) do
    receive do
      # total = total + hops
      #{:completed,hops} -> total = total + hops
      {:completed,hop_count} -> IO.inspect hop_count
    end
    #IO.inspect hop_count
    if(i+1<cnt) do
      total = incrementHopCounter(total,i+1,cnt)
    end
    total
  end

  def findNewDest(process_list,req_count) do
    Enum.map(process_list, fn(x) -> GenServer.cast(String.to_atom(x), {:findNewDest,req_count,process_list -- [x],x})
    end)
  end

  def handle_cast({:findNewDest,req_count,process_list,x},state) do
    message_helper(process_list,req_count,x,state)
    {:noreply,state}
  end

  def message_helper(process_list,req_count,x,state) do
    #current_node = i
    #IO.inspect ["what is this",current_node]
    msg = "Message Hopper"
    for i <- 0..req_count-1 do
      dest = Enum.at(process_list,:rand.uniform(length(process_list)-1))
      #IO.inspect dest
      message_router(msg,dest,x,state,0)
    end
  end

  def message_router(msg, dest,x,state,current_counter) do
    tot = 0
    #IO.inspect ["what is this",i]
    #IO.inspect ["Dest",dest]
    if(dest == x) do
      reachedPastry(msg, dest, current_counter,tot)
    else
      new_id = findNext(dest,x,state)
      current_counter = current_counter + 1
      forward(msg, dest,new_id,current_counter,state)
    end
  end

  def forward(msg,dest,new_id,current_counter,state) do
    self_key = Process.info(self) |> Enum.at(0) |> elem(1)
    GenServer.cast(String.to_atom(new_id),{:forward,msg,dest,current_counter})
  end

  def handle_cast({:forward,msg,dest,current_counter},state) do
    self_key = Atom.to_string(Process.info(self) |> Enum.at(0) |> elem(1))
    message_router(msg,dest,self_key,current_counter,state)
    {:noreply,state}
  end
  # def forward(msg,dest,new_id,current_counter,state) do
  #   self_node = elem(elem(Enum.at(Process.info(self),0),1)
  #   GenServer.cast(String.to_atom(new_id),{:forwardmsg,msg,dest,current_counter})
  # end

  # def handle_cast({:forwardmsg,msg,dest,current_counter},state) do
  #   self_node = Atom.to_string(elem(elem(Enum.at(Process.info(self),0),1)
  #   message_router(msg,dest,self_node,state,current_counter)
  #   {:noreply,state}
  # end



  def reachedPastry(msg, dest, hops,tot) do
     #IO.inspect "abc"
    send(:main, {:completed,hops})
    # tot = tot + hops
    # addHops(tot)
  end

  def addHops(tot) do
    tot
  end

  def findNext(dest,x,state) do
    lset = Enum.at(state,0)

    if(List.last(lset) >= dest && List.first(lset) <= dest) do
      #IO.inspect "Check"
      searchLeaf(dest,lset)
    else
      hexa_val = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
      rtable = Enum.at(state,1)
      
      findRow = largestMatchedPrefix(x,dest)
      findCol = Enum.find_index(hexa_val, fn(i) -> 
        String.at(dest,findRow) == i
      end)

      if((Enum.at(Enum.at(rtable,findRow),findCol)) != nil) do
        Enum.at(Enum.at(rtable,findRow),findCol)
      else
        fullSet = lset

        res =  Enum.reduce_while(fullSet,0,fn(i,acc)-> 
          if(largestMatchedPrefix(i,dest) >= findRow && kwDiff(dest,i) < kwDiff(dest,x)) do
            {:halt, i}
          else
            {:cont, acc}
          end
        end)
        if(res == 0) do
          #IO.inspect "reached"
          x
        else
          res
        end
      end
    end
  end

  def largestMatchedPrefix(currentdest,dest) do
    IO.inspect ["Destination",dest]
    IO.inspect ["Current",currentdest]
    # # # #IO.puts("abc")
    # kwList = String.myers_difference(currentdest,dest)
    # #IO.inspect kwList
    # headVal = hd(kwList)

    # if(elem(headVal,0) == :eq) do
    #   prefix = Keyword.get(kwList,:eq)
    #   strlen = String.length(prefix)
    #   strlen
    # else
    #   0
    # end
    #IO.inspect "check"
    strlen = 0
    index_val = 0
    if(String.at(currentdest,index_val) == String.at(dest,index_val)) do
      strlen = strlen + 1
      index_val = index_val + 1
      largestMatchedPrefix(Enum.slice(currentdest,index_val..length(currentdest)-1),Enum.slice(dest,index_val..length(dest)-1))
    end
    strlen
  end

  def kwDiff(val1,val2) do
    abs(elem(Integer.parse(val1,16),0) - elem(Integer.parse(val2,16),0))
  end

  def searchLeaf(dest,lset) do
    int_dest = elem(Integer.parse(dest,16),0)
    int_lset = Enum.map(lset, fn(i) -> elem(Integer.parse(dest,16),0) 
    end)
    int_nearestDest = Enum.reduce(int_lset,fn(i,acc)->
      if(abs(int_dest-i)>=acc) do
        acc
      else
        i
      end
    end)
    Integer.to_string(int_nearestDest,16)
  end

  def init(nodeID) do
    leafSet = []
    routingTable = [[]]
    {:ok,[leafSet,routingTable]}
  end

  def createNodesandActors(numNodes,numRequests) do
    process_list = Enum.reduce(1..numNodes, [], fn(i,acc) ->
    nodeID = :crypto.hash(:md5,"#{i}") |> Base.encode16
    processID = GenServer.start_link(__MODULE__,{numNodes,numRequests}, name: String.to_atom(nodeID))
    acc ++ [nodeID]
    end)
    #IO.inspect process_list
    sorted_list = Enum.sort(process_list)
    Enum.map(sorted_list,fn(i) -> stInit(sorted_list,i)end)
    sorted_list
  end

  #leafset and routing table
  def stInit(sorted_list, processID) do
    hexa_val = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
    len = length(sorted_list)
    current_index = Enum.find_index(sorted_list,fn(i) -> i == processID end)
    if(current_index - 8 >= 0) do
      lowerbound = current_index - 8
    else
      lowerbound = 0;
    end

    if(current_index + 8 <= len - 1) do
      upperbound = current_index + 8
    else
      upperbound = len - 1;
    end
    
    low_surplus = current_index-8
    upp_surplus = current_index+8

    if(low_surplus >= 0 && upp_surplus <= len-1) do
      leafSet =  Enum.slice(sorted_list,lowerbound..upperbound) -- [Enum.at(sorted_list,current_index)]
      Enum.sort(leafSet)
    end

    if(low_surplus < 0) do
      leafSet =  Enum.slice(sorted_list,lowerbound..upperbound) ++ Enum.slice(sorted_list,len-abs(low_surplus)+1..len-1) -- [Enum.at(sorted_list,current_index)]
      Enum.sort(leafSet)  
    end

    if(upp_surplus >= len) do
      leafSet =  Enum.slice(sorted_list,0..(upp_surplus-len)) ++ Enum.slice(sorted_list,lowerbound..upperbound) -- [Enum.at(sorted_list,current_index)]
      Enum.sort(leafSet)
    end 
    #IO.inspect leafSet
    #IO.inspect sorted_list
    checkNewLeafs(leafSet,processID)
    rtable = findRouteTable(sorted_list,processID,hexa_val) #routing table
    #IO.inspect rtable
    newRoutingTable(rtable, processID) # process new routing table
  
  end
  
  def findRouteTable(sorted_list,processID,hexa_val) do
    routetable_list = sorted_list -- [processID]
    createRoutingTable(routetable_list,processID,hexa_val)
  end

  def createRoutingTable(routetable_list,processID,hexa_val) do
    rtable = Enum.reduce(1..32,[],fn(i,acc) -> 
      matched_prefix = String.slice(processID,0,i-1)
      matched_row = correspondingrowValue(matched_prefix,routetable_list,hexa_val)
      acc ++ [matched_row]
    end)
    rtable
  end

  def correspondingrowValue(matched_prefix,routetable_list,hexa_val) do
    matched_row = Enum.map(hexa_val,fn(i) -> Enum.find(routetable_list, fn(j) -> String.starts_with?(j,matched_prefix<>i)end)end)
    matched_row
  end

  def newRoutingTable(rtable, processID) do
    GenServer.cast(String.to_atom(processID), {:routing_new,rtable})
  end

  def handle_cast({:routing_new,rtable},state) do
    state = List.replace_at(state,1,rtable)
    {:noreply,state}
  end

  def checkNewLeafs(leafSet,processID) do
    GenServer.cast(String.to_atom(processID),{:leaf_new,leafSet})
    #IO.inspect "abc"
  end
  
  def handle_cast({:leaf_new,leafSet},state) do
    state = List.replace_at(state,0,leafSet)
    {:noreply,state}
  end


end
