use encoding 'euc-jp';
use Test::More tests => 1;

my @a;

while (<DATA>) {
  chomp;
  tr/��-��-��/��-��-��/;
  push @a, $_;
}

SKIP: {
  skip("pre-5.8.1 does not do utf8 DATA", 1) if $] < 5.008001;
  ok(@a == 3 &&
     $a[0] eq "�����DATA�դ�����Ϥ�ɤ�ΤƤ��ȥǥ���" &&
     $a[1] eq "���ܸ쥬�������Ѵ��ǥ��륫" &&
     $a[2] eq "�ɥ����ΤƤ��ȥ򥷥ƥ��ޥ���",
     "utf8 (euc-jp) DATA")
}

__DATA__
�����DATA�ե�����ϥ�ɥ�Υƥ��ȤǤ���
���ܸ줬�������Ѵ��Ǥ��뤫
�ɤ����Υƥ��Ȥ򤷤Ƥ��ޤ���
