use Perl6::Form


print: $^STDOUT, < form: \(%: interleave=>1,,single=>'^'),\(%: single=>'='),\(%: single=>'_')
                         <<'.', <
~~~~~~~~~
^ = ^ _ ^ {|||}
~~~~~~~~~
.
                                         qw(China's first taikonaut lands safely okay!)

print: $^STDOUT, "\n--------------------------\n\n"

print: $^STDOUT, < form: \(%: single=>'='), \(%: interleave=>1), <<'.'
   ^
 = | {""""""""""""""""""""""""""""""""""""}
   +--------------------------------------->
    {|||||||||||||||||||||||||||||||||||}
.
                         "Height", \(@:  ~< $^DATA), "Time"


print: $^STDOUT, < form: <<'.'
Passed:
	{[[[[[[[[[[[[[[[[[[[}
Failed:
	{[[[[[[[[[[[[[[[[[[[}
.
                         \qw(Smith Simmons Sutton Smee), \qw(Richards Royce Raighley)


print: $^STDOUT, < form: \(%: interleave=>1), <<'.'
Passed:
	{[[[[[[[[[[[[[[[[[[[}
Failed:
	{[[[[[[[[[[[[[[[[[[[}
.
                         \qw(Smith Simmons Sutton Smee), \qw(Richards Royce Raighley)

__DATA__
      *
    *   *
   *     *
          
  *       *
           
 *         *
          
         
        
*           *

