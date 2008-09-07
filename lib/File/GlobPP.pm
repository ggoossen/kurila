package File::GlobPP;

sub glob {
    my $pat = shift;

    #open my $outfh, "-|", "echo $pat |tr -s ' \t\f\r' '\\n\\n\\n\\n'" or die;
    open my $outfh,"-|", "csh -cf 'set nonomatch; glob $pat' 2>/dev/null" or die;
    local $/ = "\0";
    my $files = @( ~< $outfh );
    close $outfh or die;
    return $files;
}

1;
