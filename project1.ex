defmodule Server do
    def serversetup do
      {:ok, addrs} = :inet.getif
      {inner_addrs, _, _} = Enum.at(addrs,0)
      {first, second, third, fourth} = inner_addrs
      ip = "#{first}.#{second}.#{third}.#{fourth}"

      #hack for windows ip address
      if ip == "127.0.0.1" do
            {:ok, addrs}= :inet.getif
            {inner_addrs, _, _} = Enum.at(addrs,1)
            {first, second, third, fourth} = inner_addrs
            ip = "#{first}.#{second}.#{third}.#{fourth}"
       end

      servername = "bitcoinserver@#{ip}"
      servername_atom = String.to_atom(servername)
      Node.start(servername_atom)
      Node.set_cookie(Node.self(), :"mycookie")
    end

  def actor_generator do
    receive do
      {k} -> generate_hash(k)
    end
    actor_generator
  end

  def active_workers do
    receive do
      {:message, k} -> check_worker_connection(k,0)
    end
  end

  def check_worker_connection(k,size) do
    newsize = Kernel.length(Node.list)
      if newsize - size>0 do
        diff = newsize - size
        generate_worker(Node.list, size, diff, k)
      end
      check_worker_connection(k,newsize)
  end

  def generate_worker(list, s, diff, k) do
    if diff != 0 do
        newnode = Enum.at(list, s+diff-1)
        workerpid = Node.spawn(newnode, Worker, :worker_msg_recv, [8])
        send workerpid, {:message, k}
        generate_worker(list, s, diff-1, k)
    end
  end
    
  def generate_hash(k) do
    random_input = :crypto.strong_rand_bytes(5) |> Base.encode64 |> binary_part(0,5) #Random string of length 5 as per the assignment doc
    random_string = Enum.join(["vagisha", random_input], ";")
    crypto_string = Base.encode16(:crypto.hash(:sha256, random_string))
    c = String.to_integer(k) # String.pad_leading("",k,"0")
    isvalidhash = String.slice(crypto_string,0..c-1) |> String.to_charlist |> Server.check_numberof_zeros
    if isvalidhash == true do
      #{:ok, file} = File.open("newfile.txt", [:append])
      #IO.binwrite(file, "#{str} \t #{hash}\n")
      IO.puts "#{random_string} \t #{crypto_string}"
    end
  end

  def check_numberof_zeros(list) do
    Enum.all?(list, fn x -> x == 48 end)
  end

  def call_actors(k) do
    core = System.schedulers_online
    total = (core*2)+2
    pids = Enum.map(1..total, fn (_) -> spawn(&Server.actor_generator/0) end)
    Enum.each pids, fn pid -> 
      sendmessage(pid, k)
    end
  end

  def sendmessage(pid, k) do
    send(pid, {k})
    sendmessage(pid, k)
  end
end


defmodule Worker do
    def worker_msg_recv(k)  do
        receive do
            {:message, k} -> worker_actor_generator(k)
        end   
    end

    def worker_actor_call(k) do
        receive do
            {pid, k} -> worker_generate_hash(pid, k)
        end
        worker_actor_call(k)
    end

    def worker_actor_generator(k) do
        core = System.schedulers_online
        total = (core*2)+2
        pids = Enum.map(1..total, fn (_) -> Node.spawn(Node.self, Worker, :worker_actor_call, [k]) end)
        Enum.each pids, fn pid ->
          sendmessage(pid,k)
        end
    end

    def sendmessage(pid, k) do
      send(pid, {k})
      sendmessage(pid, k)
    end

    def worker_generate_hash(pid, k) do
        random_input = :crypto.strong_rand_bytes(5) |> Base.encode64 |> binary_part(0,5) #Random string length = 5
        random_string = Enum.join(["vagisha", random_input], ";")
        crypto_string = Base.encode16(:crypto.hash(:sha256, random_string))
        isvalid_coin = String.slice(crypto_string,0..k-1) |> String.to_charlist |> Worker.check_numberof_zeros
        if isvalid_coin == true do
            IO.puts "#{random_string} \t #{crypto_string}"   
        end
    end

    def check_numberof_zeros(list) do
        Enum.all?(list, fn x -> x == 48 end)
    end

    def worker_runinfinite do
      worker_runinfinite()
    end

    def main(server_ip) do
        {:ok, addrs} = :inet.getif
        {inner_addrs, _, _} = Enum.at(addrs,0)
        {first, second, third, fourth} = inner_addrs
        ip = "#{first}.#{second}.#{third}.#{fourth}"

        #hack for windows ip address
      if ip == "127.0.0.1" do
            {:ok, addrs}= :inet.getif
            {inner_addrs, _, _} = Enum.at(addrs,1)
            {first, second, third, fourth} = inner_addrs
            ip = "#{first}.#{second}.#{third}.#{fourth}"
       end

        workername = "bitcoinworker@#{ip}"
        workername_atom = String.to_atom(workername)
        servername = "bitcoinserver@#{server_ip}"
        servername_atom = String.to_atom(servername)

        Node.start(workername_atom)
        Node.set_cookie(Node.self(), :"mycookie")
        Node.connect(servername_atom)
        worker_runinfinite()
    end
end

# Cores

defmodule Project1 do
  def main(args) do
    if List.first(args) =~ "." == true do
        Worker.main(List.first(args))
    else
      Server.serversetup
      input_length = String.length(List.first(args))
      kvalue = String.slice(List.first(args),0..input_length-1) # use this check to detect for \n 
      msg = String.to_integer(kvalue)
      serverconnectioncheckpid = spawn(&Server.active_workers/0)
      send serverconnectioncheckpid, {:message, msg}
      Server.call_actors(List.first(args)) #local in file
    end 
  end
end