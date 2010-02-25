use Perl6::Form

print: $^STDOUT, < form: \(%: single=>'^'),\(%: single=>'='),\(%: single=>'_')
                         '~~~~~~~~~'
                         '^ _ = _ ^', <
                                         qw(Like round and orient perls)
                         '~~~~~~~~~'

print: $^STDOUT, "\n--------------------------\n\n"

print: $^STDOUT, < form: \(%: single=>'=')
                         '   ^'
                         ' = | {""""""""""""""""""""""""""""""""""""}'
                         "Height"
                         \(@:  ~< $^DATA)
                         '   +------------------------------------->'
                         '    {|||||||||||||||||||||||||||||||||||}'
                         "Time"

__DATA__
      *
    *   *
   *     *
          
  *       *
           
 *         *
          
         
        
*           *

