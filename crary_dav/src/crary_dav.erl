-module(crary_dav).

-export([handler/2]).

-include("crary.hrl").
-include("uri.hrl").

handler(Req, BaseDir) ->
    io:format("~nreq: ~p~n", [crary:pp(Req)]),
    case Req#crary_req.method of
        "GET"      -> crary_dir_listing:handler(Req, BaseDir);
        "HOST"     -> crary_dir_listing:handler(Req, BaseDir);
        "MKCOL"    -> mkcol(Req, BaseDir);
        "PROPFIND" -> propfind(Req, BaseDir);
        "OPTIONS"  -> options(Req, BaseDir);
        _          -> crary:not_implemented(Req)
    end.

mkcol(Req, BaseDir) ->
    Uri = (Req#crary_req.uri)#uri.raw,
    try crary_dir_listing:ile_path(Req, BaseDir) of
        Path ->
            case file:make_dir(Path) of
                ok ->
                    crary:r(Req, created, []),
                    crary_sock:done_writing(Req);
                {error, eaccess} ->
                    crary:r_error(Req, forbidden,
                                  [<<"Access denied creating ">>, Uri]);
                {error, eexist} ->
                    crary:r_error(Req, method_not_allowed,
                                  [<<"The resource ">>, Uri,
                                   <<" already exists">>]);
                {error, enoent} ->
                    crary:r_error(Req, conflict,
                                  [<<"The parent of URL ">>, Uri,
                                   <<"does not exist">>]);
                {error, enospc} ->
                    crary:r_error(Req, <<"507 Insufficient Storage">>,
                                  [<<"No space to create ">>, Uri]);
                {error, enotdir} ->
                    crary:r_error(Req, forbidden,
                                  [<<"Parent for ">>, Uri,
                                   <<" is not a directory">>])
            end
    catch
        {invalid_path, _Path} ->
            crary:r_error(Req, forbidden,
                          [<<"MKCOL not allowed in URL ">>, Uri])
    end.

propfind(Req, _BaseDir) ->
    try parse_propfind_xml(crary_body:read_all(Req)) of


    try xmerl_scan:string(Body) of
        {#xmlElement{name = xb_propfind, content = } = XmlBody, ""} ->

        {_Res, ""}
            crary:error(Req, <<"422 Unprocessable Entity">>,
                        <<"XML requesty body contained unknown elements.">>)
    catch
        exit:{fatal, R} ->
            crary:error(Req, 400, <<"Malformed XML request body.">>)
    end.

parse_propfind_xml(Str) ->
    {ok, P} = expat:start_link(self()),
    expat:parse(Str),
    parse_propfind_xml_root().

parse_propfind_xml_root() ->
    receive
	{start, "DAV:", "propfind", _Attrs} ->
	    parse_propfind_xml_l1();
	{start, _NS, _Tag, _Attrs} ->
	    throw(422);
	{error, _Str} ->
	    throw(400)
    end.

parse_propfind_xml_l1() ->
    receive
	{start, "DAV:", "allprop", _Attrs} ->
	    allprops;
	{start, "DAV:", "propname", _Attrs} ->
	    propname;
	{start, "DAV:", "prop", _Attrs} ->
	    parse_propfind_xml_props([]);
	{start, _NS, _Tag, _Attrs} ->
	    throw(422);
	{error, _Str} ->
	    throw(400)
    end.

parse_propfind_xml_props(Acc) ->
    receive
	{start, NS, Tag, _Attrs} ->
	    receive
		{end, NS, Tag} ->
		    parse_propfind_xml_props([{Ns, Tag} | Acc]);
		_ ->
		    throw(422)
	    end;
	->

    end.


options(Req, _BaseDir) ->
    crary:r(Req, ok, [{<<"Allow">>, <<"OPTIONS, GET, MKCOL">>}]).

