-module(gitr).
-behavior(gen_server).

-export([init/1,handle_info/2,start/0]).
-export([parse_body/1]).

-record(state, {session}).

-record(commit, {repo, committer, branch, message, url}).


% These are just stubbed...
-export([handle_call/3, handle_cast/2, code_change/3,terminate/2]).

-include_lib("exmpp/include/exmpp.hrl").
-include_lib("exmpp/include/exmpp_client.hrl").

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	{ok, SecretWrapped} = init:get_argument(secret),
	{ok, SubdomainWrapped} = init:get_argument(subdomain),
	{ok, PortStrWrapped} = init:get_argument(port),
	[[Subdomain]] = SubdomainWrapped,
	[[Secret]] = SecretWrapped,
	[[PortStr]] = PortStrWrapped,
	io:format("PortStr ~w~n", [Secret]),
	io:format("PortStr ~w~n", [PortStr]),
	Port = list_to_integer(PortStr),
	exmpp:start(), 
	Session = exmpp_component:start_link(),
	exmpp_component:auth(Session, Subdomain, Secret),
	_StreamId = exmpp_component:connect(Session, "localhost", Port),
	ok = exmpp_component:handshake(Session),
	{ok, #state{session = Session}}.

handle_info(#received_packet{} = Packet, #state{session = Session} = State) ->
	spawn(
		fun() ->
			process_received_packet(Session, Packet)
		end),
	{noreply, State};

handle_info(_Other, #state{session = _Session} = State) ->
	{noreply, State}.

process_received_packet(Session, #received_packet{packet_type = 'message', type_attr = Type, raw_packet = Msg}) ->
    	From = exmpp_xml:get_attribute(Msg, from, <<"unknown">>),
    	io:format("Received msg of type: ~si from ~s ~n", [Type, From]),
	{jid, _FullJidBin, UserBin, _ServerBin, _ResourceBin} = exmpp_jid:parse(From),
	case UserBin of
	 <<"github-services">> -> 
		{ok, CommitInfo} = process_github_message(Session, Msg),
		{Repo, Committer, _Lines, Url} = CommitInfo,
		{ok, Details} = fetch_json(binary_to_list(Url)),
		io:format("Result...~nRepo:~s~nCommitter: ~s~nUrl: ~s~nMore Details..~n~w", [Repo,Committer, Url, Details]);
	 _Other -> ok
	end;

process_received_packet(_Session, _OtherPacket) ->
	ok.

process_github_message(_Session, Msg) ->
	Body = exmpp_message:get_body(Msg),
	io:format("Message from github with body: ~s, binary? ~s ~n", [Body, is_binary(Body)]),
	parse_body(Body).

parse_body(Body) ->
	parse_repo(Body, <<>>).

parse_repo(<<$:,Rest/binary>>, Repo) ->
	io:format("Repo: ~s~n", [Repo]),
	parse_committer(Rest, Repo, <<>>);
parse_repo(<<Ch:8,Rest/binary>>, Repo) ->
	parse_repo(Rest, <<Repo/binary,Ch:8>>).

parse_committer(<<$\ , Rest/binary>>, Repo, <<>>) ->
	parse_committer(Rest, Repo, <<>>);
parse_committer(<<$\ , Rest/binary>>, Repo, Committer) ->
	io:format("---Stage 2----~n"),
	io:format("Repo: ~s~n", [Repo]),
	io:format("Committer: ~s~n", [Committer]),
	parse_skipped(Rest, Repo, Committer);
parse_committer(<<Ch:8,Rest/binary>>, Repo, Committer) ->
	parse_committer(Rest, Repo, <<Committer/binary,Ch:8>>).

parse_skipped(<<$\n, Rest/binary>>, Repo, Committer) ->
	parse_rest(Rest, Repo, Committer, [], <<>>);
parse_skipped(<<_Ch:8, Rest/binary>>, Repo, Committer) ->
	parse_skipped(Rest, Repo, Committer).


parse_rest(<<>>, Repo, Committer, Lines, Line) ->
	{ok, {Repo, Committer, lists:reverse(Lines), Line}};
parse_rest(<<$\n>>, Repo, Committer, Lines, Line) ->
	{ok, {Repo, Committer, lists:reverse(Lines), Line}};
parse_rest(<<$\n, Rest/binary>>, Repo, Committer, Lines, Line) ->
 	parse_rest(Rest, Repo, Committer, [Line | Lines], <<>>);
parse_rest(<<Ch:8, Rest/binary>>, Repo, Committer, Lines, Line) ->
	parse_rest(Rest, Repo, Committer, Lines, <<Line/binary,Ch:8>>).

fetch_json(Url) ->
	Json = os:cmd("wget -O - --quiet --header=\"Accept: application/json\" --no-check-certificate  "++Url),
	{ok, json_eep:json_to_term(Json)}.
%%%%%%%%
%% Stubs...
%%

handle_call(_X,_Y,_Z) ->
	ok.

handle_cast(_X, _Y) ->
	ok.

code_change(_X, _Y, _Z) ->
	ok.

terminate(_X, _Y) ->
	ok.
