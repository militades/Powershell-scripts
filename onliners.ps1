# sends a ping request to loop back... 
1..254 | % {"127.0.0.$($_): $(Test-Connection -count 1 -comp 127.0.0.$($_) -quiet)"}

#Roughly translates to
ForEach ($num in 1..5) {
    $res = Test-Connection -count 1 -comp "127.0.0.$($num)" -quiet
    "127.0.0.$($num): $($res)" 
}

