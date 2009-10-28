#!./perl


use warnings

require q(./test.pl); plan: tests => 4

=pod

This tests the classic diamond inheritence pattern.

   <A>
  /   \
<B>   <C>
  \   /
   <D>

=cut

do
    package Diamond_A
    sub hello { 'Diamond_A::hello' }

do
    package Diamond_B
    use base 'Diamond_A'

do
    package Diamond_C
    use base 'Diamond_A'

    sub hello { 'Diamond_C::hello' }

do
    package Diamond_D
    use base ('Diamond_B', 'Diamond_C')
    use mro 'c3'


ok: (eq_array: 
        (mro::get_linear_isa: 'Diamond_D')
        \ qw(Diamond_D Diamond_B Diamond_C Diamond_A)
        ), '... got the right MRO for Diamond_D'

is: (Diamond_D->hello: ), 'Diamond_C::hello', '... method resolved itself as expected'
is: ((Diamond_D->can: 'hello')->& <: ), 'Diamond_C::hello', '... can(method) resolved itself as expected'
is: ((UNIVERSAL::can: "Diamond_D", 'hello')->& <: ), 'Diamond_C::hello', '... can(method) resolved itself as expected'
