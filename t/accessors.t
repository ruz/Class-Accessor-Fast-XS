#!perl
use strict;
use Test::More tests => 30;

for my $class (qw(Class::Accessor::Fast Class::Accessor::Fast::XS)) {
    require_ok($class);
    my $silly = "Silly::$class";
    {
        no strict 'refs';
        @{"${silly}::ISA"} = ($class);
        *{"${silly}::car"} = sub { shift->_car_accessor(@_); };
        *{"${silly}::mar"} = sub { return "Overloaded"; };
        $silly->mk_accessors(qw( foo bar yar car mar ));
        $silly->mk_ro_accessors(qw(static unchanged));
        $silly->mk_wo_accessors(qw(sekret double_sekret));
    }

    my $test = $silly->new({
            static       => "variable",
            unchanged    => "dynamic",
        });

    $test->foo(42);
    $test->bar('Meep');

    is($test->foo, 42, "foo accessor");
    is($test->{foo}, 42, "foo hash element");

    is($test->static, 'variable', 'ro accessor');
    eval { $test->static('foo'); };
    like(scalar $@,
        qr/^'main' cannot alter the value of 'static' on objects of class '$silly'/,
        'ro accessor write protection') unless $class eq 'Class::Accessor::Fast::XS';

    $test->double_sekret(1001001);
    is( $test->{double_sekret}, 1001001, 'wo accessor' );
    eval { () = $test->double_sekret; };
    like(scalar $@,
        qr/^'main' cannot access the value of 'double_sekret' on objects of class '$silly'/,
        'wo accessor read protection' ) unless $class eq 'Class::Accessor::Fast::XS';

    is($test->_foo_accessor, 42, 'accessor alias');

    $test->car("AMC Javalin");
    is($test->car, 'AMC Javalin', 'internal override access');
    is($test->mar, 'Overloaded', 'internal override constant');

    # Make sure bogus accessors die.
    eval { $test->gargle() };
    ok($@, 'bad accessor');

    # Test that the accessor works properly in list context with a single arg.
    my $test2 = $silly->new;
    my @args = ($test2->foo, $test2->bar);
    is(@args, 2, 'accessor get in list context');

    # test array setters
    $test->foo(qw(1 2 3));
    is_deeply($test->foo, [qw(1 2 3)], "set an array ref via foo accessor");

    $test->sekret(qw(1 2 3));
    is_deeply($test->{'sekret'}, [qw(1 2 3)], "array ref")
        unless $class eq 'Class::Accessor::Faster';

    {
        my $eeek;
        local $SIG{__WARN__} = sub { $eeek = shift };
        $silly->mk_accessors(qw(DESTROY));
        like($eeek,
            qr/a data accessor named DESTROY/i,
            'mk DESTROY accessor warning');
    };

    # special case for bug #45594 @ rt.cpan.org
    is $silly->new->static, undef, 'RO accessor without value should return undef';
}
