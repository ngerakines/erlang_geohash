-module(geohash).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").

geohash_test_() ->
    
    [
        ?_assert(geohash:encode(42.6, -5.6) == "ezs42"), %% 0.01
        ?_assert(geohash:encode(-20, 50) == "mh7w"), %% 0.1
        ?_assert(geohash:encode(10.1, 57.2) == "t3b9m"), %% 0.01
        ?_assert(geohash:encode(49.26, -123.26) == "c2b25p"), %% 0.01
        ?_assert(geohash:encode(0.005, -179.567) == "80021bgm"), %% 0.001
        ?_assert(geohash:encode(-30.55555, 0.2) == "k484ht99h2"), %% 0.00001
        ?_assert(geohash:encode(5.00001, -140.6) == "8buh2w4pnt") %% 0.00001
    ].

base26(0) -> $0;
base26(1) -> $1;
base26(2) -> $2;
base26(3) -> $3;
base26(4) -> $4;
base26(5) -> $5;
base26(6) -> $6;
base26(7) -> $7;
base26(8) -> $8;
base26(9) -> $9;
base26(10) -> $b;
base26(11) -> $c;
base26(12) -> $d;
base26(13) -> $e;
base26(14) -> $f;
base26(15) -> $g;
base26(16) -> $h;
base26(17) -> $j;
base26(18) -> $k;
base26(19) -> $m;
base26(20) -> $n;
base26(21) -> $p;
base26(22) -> $q;
base26(23) -> $r;
base26(24) -> $s;
base26(25) -> $t;
base26(26) -> $u;
base26(27) -> $v;
base26(28) -> $w;
base26(29) -> $x;
base26(30) -> $y;
base26(31) -> $z.

encode(Lat, Lon) ->
    Pres = geohash:precision(Lat, Lon),
    geohash:encode(Lat, Lon, Pres).

encode(Lat, Lon, Pres) ->
    geohash:encode_major(Pres, {Lat, Lon}, {{90, -90 }, {180, -180}}, 1, []).

encode_major(0, {_Lat, _Lon}, _Set, _Flip, Acc) -> lists:reverse(Acc);
encode_major(X, {Lat, Lon}, Set, Flip, Acc) ->
    {Code, NewSet, NewFlip} = geohash:encode_minor(0, {Lat, Lon}, Set, 0, Flip),
    encode_major(X - 1, {Lat, Lon}, NewSet, NewFlip, [Code | Acc]).

encode_minor(5, _, Set, Bits, Flip) -> {base26(Bits), Set, Flip};
encode_minor(X, {Lat, Lon}, Set, Bits, Flip) ->
    Mid = geohash:mid(Flip, Set),
    Bit = case geohash:latlon(Flip, {Lat, Lon}) >= Mid of true -> 1; _ -> 0 end,
    NewBits = (Bits bsl 1) bor Bit,
    NewSet = geohash:shiftset(Set, Flip, Bit, Mid),
    encode_minor(X + 1, {Lat, Lon}, NewSet, NewBits, geohash:flip(Flip)).

flip(0) -> 1;
flip(_) -> 0.

shiftset({{A, B}, {_, D}}, 1, 0, New) -> {{A, B}, {New, D}};
shiftset({{A, B}, {C, _}}, 1, 1, New) -> {{A, B}, {C, New}};
shiftset({{_, B}, {C, D}}, 0, 0, New) -> {{New, B}, {C, D}};
shiftset({{A, _}, {C, D}}, 0, 1, New) -> {{A, New}, {C, D}}.

latlon(0, {X, _}) -> X;
latlon(1, {_, X}) -> X.

mid(0, {{A, B}, _}) -> (A + B) / 2;
mid(1, {_, {A, B}}) -> (A + B) / 2.

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

number_to_list(X) when is_float(X) -> float_to_list(X);
number_to_list(X) when is_integer(X) -> integer_to_list(X).
