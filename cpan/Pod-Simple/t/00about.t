
# Time-stamp: "2004-05-23 19:48:32 ADT"

# Summary of, well, things.


use Test::More
my @modules
BEGIN 
    @modules = qw(

Pod::Escapes

Pod::Simple	
Pod::Simple::BlackBox	Pod::Simple::Checker	Pod::Simple::DumpAsText
Pod::Simple::DumpAsXML	Pod::Simple::HTML	Pod::Simple::HTMLBatch
Pod::Simple::HTMLLegacy	Pod::Simple::LinkSection	Pod::Simple::Methody
Pod::Simple::Progress	Pod::Simple::PullParser
Pod::Simple::PullParserEndToken	Pod::Simple::PullParserStartToken
Pod::Simple::PullParserTextToken	Pod::Simple::PullParserToken
Pod::Simple::RTF	Pod::Simple::Search	Pod::Simple::SimpleTree
Pod::Simple::Text	Pod::Simple::TextContent
Pod::Simple::Transcode	Pod::Simple::XMLOutStream

  )
    plan: tests => 2 + nelems @modules
;

ok: 1

#chdir "t" if -e "t";
foreach my $m ( @modules)
    print: $^STDOUT, "# Loading $m ...\n"
    eval "require $m;"
    die: if $^EVAL_ERROR
    ok: 1


ok: 1

