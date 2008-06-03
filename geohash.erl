-module(geohash).
-compile(export_all).

-author("Nick Gerakines <nick@gerakines.net>").
-version("0.1").

-include_lib("eunit/include/eunit.hrl").

%% -
%% Unit tests

geohash_test_() ->
    Tests = [
        {42.6, -5.6, "ezs42"}, {-20, 50, "mh7w"}, {10.1, 57.2, "t3b9m"},
        {49.26, -123.26, "c2b25p"}, {0.005, -179.567, "80021bgm"},
        {-30.55555, 0.2, "k484ht99h2"}, {5.00001, -140.6, "8buh2w4pnt"}],
    [begin
        ?_assert(geohash:encode(A, B) == C)
    % end || {A, B, C} <- Tests],
    % [begin
    %     ?_assert(geohash:decode(C) == [A, B])
    end || {A, B, C} <- Tests].

%% -
%% Base32 encoding

base_32() -> [
    {0, $0}, {1, $1}, {2, $2}, {3, $3}, {4, $4}, {5, $5}, {6, $6}, {7, $7},
    {8, $8}, {9, $9}, {10, $b}, {11, $c}, {12, $d}, {13, $e}, {14, $f},
    {15, $g}, {16, $h}, {17, $j}, {18, $k}, {19, $m}, {20, $n}, {21, $p},
    {22, $q}, {23, $r}, {24, $s}, {25, $t}, {26, $u}, {27, $v}, {28, $w},
    {29, $x}, {30, $y}, {31, $z}
].

encode_base32(X) -> {value, {_, Y}} = lists:keysearch(X, 1, base_32()), Y.

decode_base32(X) -> {value, {Y, _}} = lists:keysearch(X, 2, base_32()), Y.

%% -
%% encode functionality

encode(Lat, Lon) ->
    Pres = geohash:precision(Lat, Lon),
    geohash:encode(Lat, Lon, Pres).

encode(Lat, Lon, Pres) ->
    geohash:encode_major(Pres, {Lat, Lon}, {{90, -90 }, {180, -180}}, 1, []).

encode_major(0, {_Lat, _Lon}, _Set, _Flip, Acc) -> lists:reverse(Acc);
encode_major(X, {Lat, Lon}, Set, Flip, Acc) ->
    {Code, NewSet, NewFlip} = geohash:encode_minor(0, {Lat, Lon}, Set, 0, Flip),
    encode_major(X - 1, {Lat, Lon}, NewSet, NewFlip, [Code | Acc]).

encode_minor(5, _, Set, Bits, Flip) -> {encode_base32(Bits), Set, Flip};
encode_minor(X, {Lat, Lon}, Set, Bits, Flip) ->
    Mid = geohash:mid(Flip, Set),
    Bit = case geohash:latlon(Flip, {Lat, Lon}) >= Mid of true -> 1; _ -> 0 end,
    NewBits = (Bits bsl 1) bor Bit,
    NewSet = geohash:shiftset(Set, Flip, Bit, Mid),
    encode_minor(X + 1, {Lat, Lon}, NewSet, NewBits, geohash:flip(Flip)).

%% -
%% decode functionality

decode(Hash) ->
    Set = decode_interval(Hash),
    [mid(X, Set) || X <- [0, 1]].

decode_interval(Hash) ->
    decode_major(Hash, 1, {{90.0, -90.0}, {180.0, -180.0}}).

decode_major([], _Flip, Set) -> Set;
decode_major([Char | Chars], Flip, Set) ->
    Bits = decode_base32(Char),
    {NewSet, NewFlip} = geohash:decode_minor(0, Set, Bits, Flip),
    decode_major(Chars, NewFlip, NewSet).

decode_minor(5, Set, _Bits, Flip) -> {Set, Flip};
decode_minor(X, Set, Bits, Flip) ->
    Mid = (geohash:mid(Flip, Set)) + 0.0,
    BitPos = (Bits band 16 ) bsr 4,
    NewSet = geohash:shiftset(Set, Flip, BitPos, Mid),
    decode_minor(X + 1, NewSet, Bits bsl 1, geohash:flip(Flip)).

%% -
%% private methods

flip(0) -> 1;
flip(_) -> 0.

shiftset({{A, B}, {_, D}}, 1, BitPos, New) when BitPos == 0 -> {{A, B}, {New, D}};
shiftset({{A, B}, {C, _}}, 1, 1, New) -> {{A, B}, {C, New}};
shiftset({{_, B}, {C, D}}, 0, BitPos, New) when BitPos == 0 -> {{New, B}, {C, D}};
shiftset({{A, _}, {C, D}}, 0, 1, New) -> {{A, New}, {C, D}}.

latlon(0, {X, _}) -> X;
latlon(1, {_, X}) -> X.

mid(0, {{A, B}, _}) ->(A + B) / 2;
mid(1, {_, {A, B}}) ->(A + B) / 2.

d2b(X) -> round((X * 3.32192809488736)).

bit_for_number(N) when is_float(N) ->
    [RawChars] = io_lib:fwrite("~f", [N]),
    [_ | [FChars]] = string:tokens(string:strip(RawChars, right, $0), "."),
    geohash:d2b(length(FChars));
bit_for_number(_) -> 0.

precision(Lat, Lon) ->
    Lab = geohash:bit_for_number(Lat) + 8,
    Lob = geohash:bit_for_number(Lon) + 9,
    Lux = case Lab > Lob of true -> Lab; _ -> Lob end,
    round(Lux / 2.5).
