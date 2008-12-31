package File::GlobPP;

sub glob {
    my $pat = shift;

    #open my $outfh, "-|", "echo $pat |tr -s ' \t\f\r' '\\n\\n\\n\\n'" or die;
    open my $outfh,"-|", "csh -cf 'set nonomatch; glob $pat' 2>/dev/null" or die;
    local $^INPUT_RECORD_SEPARATOR = "\0";
    my $files = @( ~< $outfh );
    for ($files) {
        s/\0$//;
    }
    return $files;
}

1;
