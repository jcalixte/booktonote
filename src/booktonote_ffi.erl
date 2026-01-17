-module(booktonote_ffi).
-export([getenv/1, start_ocr_worker/1, send_ocr_request/1, is_ocr_worker_running/0]).

getenv(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

%% Start the OCR worker process
start_ocr_worker(ScriptPath) ->
    case whereis(ocr_worker) of
        undefined ->
            %% Spawn the worker manager process
            Parent = self(),
            Pid = spawn(fun() -> init_worker(Parent, ScriptPath) end),
            receive
                {worker_ready, ok} -> {ok, <<"Worker started">>};
                {worker_ready, {error, Reason}} -> {error, Reason}
            after 120000 ->
                {error, <<"Timeout starting worker">>}
            end;
        _Pid ->
            {ok, <<"Worker already running">>}
    end.

init_worker(Parent, ScriptPath) ->
    Cmd = "python3.11 " ++ binary_to_list(ScriptPath),
    Port = open_port({spawn, Cmd}, [
        {line, 65536},
        binary,
        use_stdio,
        exit_status
    ]),
    %% Wait for ready signal
    case wait_for_ready(Port, 120000) of
        ok ->
            register(ocr_worker, self()),
            Parent ! {worker_ready, ok},
            worker_loop(Port);
        {error, Reason} ->
            catch port_close(Port),
            Parent ! {worker_ready, {error, Reason}}
    end.

wait_for_ready(Port, Timeout) ->
    receive
        {Port, {data, {eol, Line}}} ->
            case binary:match(Line, <<"\"ready\"">>)  of
                nomatch ->
                    %% Skip non-ready lines (debug output)
                    wait_for_ready(Port, Timeout);
                _ ->
                    ok
            end;
        {Port, {data, {noeol, _}}} ->
            %% Partial line, keep waiting
            wait_for_ready(Port, Timeout);
        {Port, {exit_status, Status}} ->
            {error, list_to_binary(io_lib:format("Worker exited with status ~p", [Status]))}
    after Timeout ->
        {error, <<"Timeout waiting for worker to start">>}
    end.

worker_loop(Port) ->
    receive
        {request, From, RequestJson} ->
            port_command(Port, [RequestJson, "\n"]),
            Response = wait_for_response(Port, 300000),
            From ! {ocr_response, Response},
            worker_loop(Port);
        {Port, {exit_status, _Status}} ->
            unregister(ocr_worker),
            exit(worker_died);
        stop ->
            catch port_close(Port),
            unregister(ocr_worker),
            ok
    end.

wait_for_response(Port, Timeout) ->
    receive
        {Port, {data, {eol, Line}}} ->
            %% Check if this is a JSON response (contains "success")
            case binary:match(Line, <<"\"success\"">>)  of
                nomatch ->
                    %% Skip non-response lines (debug output)
                    wait_for_response(Port, Timeout);
                _ ->
                    {ok, Line}
            end;
        {Port, {data, {noeol, _}}} ->
            %% Partial line, keep waiting
            wait_for_response(Port, Timeout);
        {Port, {exit_status, Status}} ->
            {error, list_to_binary(io_lib:format("Worker died with status ~p", [Status]))}
    after Timeout ->
        {error, <<"OCR request timeout">>}
    end.

%% Send OCR request to the worker
send_ocr_request(RequestJson) ->
    case whereis(ocr_worker) of
        undefined ->
            {error, <<"OCR worker not running">>};
        Pid ->
            Pid ! {request, self(), RequestJson},
            receive
                {ocr_response, Response} -> Response
            after 300000 ->
                {error, <<"OCR request timeout">>}
            end
    end.

%% Check if OCR worker is running
is_ocr_worker_running() ->
    case whereis(ocr_worker) of
        undefined -> false;
        _ -> true
    end.
