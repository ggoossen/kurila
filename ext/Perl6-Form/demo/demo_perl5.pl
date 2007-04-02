format STDOUT =
 ===================================
| NAME     |    AGE     | ID NUMBER |       
|----------+------------+-----------|       
| @<<<<<<< | @||||||||| | @>>>>>>>> |
  $name,     $age,        $ID,
|===================================|       
| COMMENTS                          |
|-----------------------------------|
| ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< |~~
  $comments,
 =================================== 
.

$name = 'Damian';
$age = 39;
$ID = '000666';
$comments = <<EOC;
Do not feed after midnight. Do not expose to strange ideas. Do not allow
subject to talk for "as long as he likes".
EOC

write STDOUT;
