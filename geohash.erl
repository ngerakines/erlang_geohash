%% Copyright (c) 2008 Nick Gerakines <nick@gerakines.net>
%% 
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%% 
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
%% 
%% Change Log
%%  * 2008-10-15 ngerakines, v0.2
%%    - Added edoc friendly documentation.
%%    - Added a patch submitted by Sergei Matusevich.
%%    - Misc module organization and layout changes.
%% 
%% @author Nick Gerakines <nick@gerakines.net> [http://blog.socklabs.com/]
%% @copyright 2008 Nick Gerakines
%% @doc A module that provides basic geohash encoding and decoding.
-module(geohash).

-export([encode/2, encode/3, decode/1]).

-author("Nick Gerakines <nick@gerakines.net>").
-version("0.2").

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

geohash_test_() ->
    Tests = [
        {42.6, -5.6, "ezs42"}, {-20, 50, "mh7w"}, {10.1, 57.2, "t3b9m"},
        {49.26, -123.26, "c2b25p"}, {0.005, -179.567, "80021bgm"},
        {-30.55555, 0.2, "k484ht99h2"}, {5.00001, -140.6, "8buh2w4pnt"}],
    [?_assert(encode(A, B) == C) || {A, B, C} <- Tests].

-endif.

%% @doc Create a hash for a given latitude and longitude.
encode(Lat, Lon) when is_number(Lat), is_number(Lon) ->
    Pres = precision(Lat, Lon),
    encode(Lat, Lon, Pres).

%% @doc Create a hash for a given latitude and longitude with a specific precision.
encode(Lat, Lon, Pres) when is_number(Lat), is_number(Lon), is_number(Pres) ->
    encode_major(Pres, {Lat, Lon}, {{90, -90}, {180, -180}}, 1, []).

%% @doc Decode a geohash into a latitude and longitude.
decode(Hash) when is_list(Hash) ->
    Set = decode_interval(Hash),
    [mid(X, Set) || X <- [0, 1]].

%% @private
base_32() -> [
    {0, $0}, {1, $1}, {2, $2}, {3, $3}, {4, $4}, {5, $5}, {6, $6}, {7, $7},
    {8, $8}, {9, $9}, {10, $b}, {11, $c}, {12, $d}, {13, $e}, {14, $f},
    {15, $g}, {16, $h}, {17, $j}, {18, $k}, {19, $m}, {20, $n}, {21, $p},
    {22, $q}, {23, $r}, {24, $s}, {25, $t}, {26, $u}, {27, $v}, {28, $w},
    {29, $x}, {30, $y}, {31, $z}
].

%% @private
encode_base32(X) when is_integer(X), X > -1, X < 32 ->
    {value, {_, Y}} = lists:keysearch(X, 1, base_32()),
    Y.

%% @private
decode_base32(X) when is_integer(X) ->
    {value, {Y, _}} = lists:keysearch(X, 2, base_32()),
    Y.

%% @private
encode_major(0, {_Lat, _Lon}, _Set, _Flip, Acc) -> lists:reverse(Acc);
encode_major(X, {Lat, Lon}, Set, Flip, Acc) ->
    {Code, NewSet, NewFlip} = encode_minor(0, {Lat, Lon}, Set, 0, Flip),
    encode_major(X - 1, {Lat, Lon}, NewSet, NewFlip, [Code | Acc]).

%% @private
encode_minor(5, _, Set, Bits, Flip) -> {encode_base32(Bits), Set, Flip};
encode_minor(X, {Lat, Lon}, Set, Bits, Flip) ->
    Mid = mid(Flip, Set),
    Bit = case latlon(Flip, {Lat, Lon}) >= Mid of true -> 1; _ -> 0 end,
    NewBits = (Bits bsl 1) bor Bit,
    NewSet = shiftset(Set, Flip, Bit, Mid),
    encode_minor(X + 1, {Lat, Lon}, NewSet, NewBits, flip(Flip)).

%% @private
decode_interval(Hash) ->
    M = 1,
    decode_major(Hash, 1, {{90 * M, -90 * M}, {180 * M, -180 * M}}).

%% @private
decode_major([], _Flip, Set) -> Set;
decode_major([Char | Chars], Flip, Set) ->
    Bits = decode_base32(Char),
    {NewSet, NewFlip} = decode_minor(0, Set, Bits, Flip),
    decode_major(Chars, NewFlip, NewSet).

%% @private
decode_minor(5, Set, _Bits, Flip) -> {Set, Flip};
decode_minor(X, Set, Bits, Flip) ->
    Mid = mid(Flip, Set),
    BitPos = (Bits band 16 ) bsr 4,
    NewSet = shiftset(Set, Flip, BitPos, Mid),
    decode_minor(X + 1, NewSet, Bits bsl 1, flip(Flip)).

%% @private
flip(0) -> 1;
flip(_) -> 0.

%% @private
shiftset({{A, B}, {_, D}}, 1, BitPos, New) when BitPos == 0 -> {{A, B}, {New, D}};
shiftset({{A, B}, {C, _}}, 1, 1, New) -> {{A, B}, {C, New}};
shiftset({{_, B}, {C, D}}, 0, BitPos, New) when BitPos == 0 -> {{New, B}, {C, D}};
shiftset({{A, _}, {C, D}}, 0, 1, New) -> {{A, New}, {C, D}}.

%% @private
latlon(0, {X, _}) -> X;
latlon(1, {_, X}) -> X.

%% @private
mid(0, {{A, B}, _}) -> (A + B) / 2;
mid(1, {_, {A, B}}) -> (A + B) / 2.

%% @private
d2b(X) -> round((X * 3.32192809488736)).

%% @private
bit_for_number(N) when is_float(N) ->
    [RawChars] = io_lib:fwrite("~f", [N]),
    [_ | [FChars]] = string:tokens(string:strip(RawChars, right, $0), "."),
    d2b(length(FChars));
bit_for_number(_) -> 0.

%% @private
precision(Lat, Lon) ->
    Lab = bit_for_number(Lat) + 8,
    Lob = bit_for_number(Lon) + 9,
    Lux = case Lab > Lob of true -> Lab; _ -> Lob end,
    round(Lux / 2.5).
