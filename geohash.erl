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

-export([encode/1, encode/2, decode/1]).

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
encode(#{lat := Lat, lon := Lon} = Pos) when is_number(Lat), is_number(Lon) ->
    Pres = precision(Pos),
    encode(Pos, Pres).

%% @doc Create a hash for a given latitude and longitude with a specific precision.
encode(#{lat := Lat, lon := Lon}, Pres) when is_number(Lat), is_number(Lon), is_number(Pres) ->
    encode_major(Pres, {Lat, Lon}, {{90, -90}, {180, -180}}, 1, []).

%% @doc Decode a geohash into a latitude and longitude.
decode(Hash) when is_list(Hash) ->
    Set = decode_interval(Hash),
    [Lat, Lon] = [mid(X, Set) || X <- [0, 1]],
    #{lat => Lat, lon => Lon}.

%% @private
encode_base32( 0) -> $0;
encode_base32( 1) -> $1;
encode_base32( 2) -> $2;
encode_base32( 3) -> $3;
encode_base32( 4) -> $4;
encode_base32( 5) -> $5;
encode_base32( 6) -> $6;
encode_base32( 7) -> $7;
encode_base32( 8) -> $8;
encode_base32( 9) -> $9;
encode_base32(10) -> $b;
encode_base32(11) -> $c;
encode_base32(12) -> $d;
encode_base32(13) -> $e;
encode_base32(14) -> $f;
encode_base32(15) -> $g;
encode_base32(16) -> $h;
encode_base32(17) -> $j;
encode_base32(18) -> $k;
encode_base32(19) -> $m;
encode_base32(20) -> $n;
encode_base32(21) -> $p;
encode_base32(22) -> $q;
encode_base32(23) -> $r;
encode_base32(24) -> $s;
encode_base32(25) -> $t;
encode_base32(26) -> $u;
encode_base32(27) -> $v;
encode_base32(28) -> $w;
encode_base32(29) -> $x;
encode_base32(30) -> $y;
encode_base32(31) -> $z.

%% @private
decode_base32($0) ->  0;
decode_base32($1) ->  1;
decode_base32($2) ->  2;
decode_base32($3) ->  3;
decode_base32($4) ->  4;
decode_base32($5) ->  5;
decode_base32($6) ->  6;
decode_base32($7) ->  7;
decode_base32($8) ->  8;
decode_base32($9) ->  9;
decode_base32($b) -> 10;
decode_base32($c) -> 11;
decode_base32($d) -> 12;
decode_base32($e) -> 13;
decode_base32($f) -> 14;
decode_base32($g) -> 15;
decode_base32($h) -> 16;
decode_base32($j) -> 17;
decode_base32($k) -> 18;
decode_base32($m) -> 19;
decode_base32($n) -> 20;
decode_base32($p) -> 21;
decode_base32($q) -> 22;
decode_base32($r) -> 23;
decode_base32($s) -> 24;
decode_base32($t) -> 25;
decode_base32($u) -> 26;
decode_base32($v) -> 27;
decode_base32($w) -> 28;
decode_base32($x) -> 29;
decode_base32($y) -> 30;
decode_base32($z) -> 31.

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
precision(#{lat := Lat, lon := Lon}) ->
    Lab = bit_for_number(Lat) + 8,
    Lob = bit_for_number(Lon) + 9,
    Lux = case Lab > Lob of true -> Lab; _ -> Lob end,
    round(Lux / 2.5).
