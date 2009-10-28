package File::GlobPP

use Config < qw(config_value)
my $has_csh = defined config_value: "d_csh"

sub glob(?$pat, ?_)

    open: my $outfh,"-|"
          ( $has_csh
          ?? "$((config_value: 'csh')) -cf 'set nonomatch; glob $pat' 2>/dev/null"
              !! "echo $pat |tr -s ' \t\f\r' '\\n\\n\\n\\n'" )
        or die: 
    local $^INPUT_RECORD_SEPARATOR = $has_csh ?? "\0" !! "\n" 
    my $files = @: ~< $outfh 
    close $outfh or die: 
    for ($files)
        s/$^INPUT_RECORD_SEPARATOR$//
    
    return $files


1
