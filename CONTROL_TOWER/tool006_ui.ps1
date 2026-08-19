param([Parameter(Mandatory=$true)][string]$Root,[switch]$SelfTest)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$engine=Join-Path $Root 'CONTROL_TOWER\tool006_engine.ps1'
if(-not(Test-Path -LiteralPath $engine -PathType Leaf)){throw "TOOL006 engine not found: $engine"}

$form=New-Object Windows.Forms.Form
$form.Text='TOOL006 TOC Organizer';$form.Width=1240;$form.Height=820;$form.StartPosition='CenterScreen'
$input=New-Object Windows.Forms.TextBox;$input.Multiline=$true;$input.ScrollBars='Both';$input.WordWrap=$false;$input.SetBounds(20,90,570,560)
$output=New-Object Windows.Forms.RichTextBox;$output.ReadOnly=$true;$output.WordWrap=$false;$output.SetBounds(620,90,580,560)
$run=New-Object Windows.Forms.Button;$run.Text='Organize';$run.SetBounds(20,20,110,42)
$clear=New-Object Windows.Forms.Button;$clear.Text='Clear';$clear.SetBounds(140,20,90,42)
$copy=New-Object Windows.Forms.Button;$copy.Text='Copy output';$copy.SetBounds(240,20,110,42)
$publisher=New-Object Windows.Forms.TextBox;$publisher.Text='UNKNOWN';$publisher.SetBounds(370,20,180,28)
$report=New-Object Windows.Forms.TextBox;$report.Text='UNKNOWN';$report.SetBounds(560,20,180,28)
$errorType=New-Object Windows.Forms.ComboBox;$errorType.DropDownStyle='DropDownList';[void]$errorType.Items.AddRange(@('NONE','PARENT_ORDER','LINE_SPLIT','NOISE_REMAINS','DEPTH','MISSING_PARENT','DUPLICATE_NUMBER','OTHER'));$errorType.SelectedIndex=0;$errorType.SetBounds(750,20,190,28)
$corrected=New-Object Windows.Forms.TextBox;$corrected.Multiline=$true;$corrected.ScrollBars='Vertical';$corrected.SetBounds(20,680,1180,70)
$status=New-Object Windows.Forms.Label;$status.Text='READY';$status.SetBounds(960,25,240,30)
$leftLabel=New-Object Windows.Forms.Label;$leftLabel.Text='Original TOC';$leftLabel.SetBounds(20,70,200,20)
$rightLabel=New-Object Windows.Forms.Label;$rightLabel.Text='Organized output (orange = review)';$rightLabel.SetBounds(620,70,300,20)
$fixLabel=New-Object Windows.Forms.Label;$fixLabel.Text='User-corrected output (optional; saved as next fixture candidate)';$fixLabel.SetBounds(20,660,500,20)
$form.Controls.AddRange(@($input,$output,$run,$clear,$copy,$publisher,$report,$errorType,$corrected,$status,$leftLabel,$rightLabel,$fixLabel))

$run.Add_Click({
    try{
        $args=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$engine,'-Root',$Root,'-InputText',$input.Text,'-Publisher',$publisher.Text,'-ReportId',$report.Text)
        if($errorType.SelectedItem -and $errorType.SelectedItem -ne 'NONE'){$args+=@('-ErrorType',[string]$errorType.SelectedItem)}
        if($corrected.Text){$args+=@('-CorrectedOutput',$corrected.Text)}
        $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
        if($process.ExitCode -ne 0){throw "Engine exit code $($process.ExitCode)"}
        $state=Get-Content -LiteralPath (Join-Path $Root 'TOOL006_TOC\tool_state.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $evidence=Get-Content -LiteralPath (Join-Path $Root 'TOOL006_TOC\evidence\tool006_evidence.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $output.Text=Get-Content -LiteralPath $state.OUTPUT_PATH -Raw -Encoding UTF8
        $output.SelectAll();$output.SelectionColor=[Drawing.Color]::Black
        foreach($hold in @($evidence.HOLD_LINES)){if($hold.text){$start=$output.Text.IndexOf([string]$hold.text,[StringComparison]::OrdinalIgnoreCase);if($start -ge 0){$output.Select($start,([string]$hold.text).Length);$output.SelectionColor=[Drawing.Color]::DarkOrange}}}
        $output.Select(0,0);$status.Text="$($state.FINAL_STATUS) / HOLD=$($evidence.HOLD_COUNT)"
    }catch{$status.Text='HOLD: '+$_.Exception.Message}
})
$clear.Add_Click({$input.Clear();$output.Clear();$corrected.Clear();$status.Text='READY'})
$copy.Add_Click({if($output.Text){[Windows.Forms.Clipboard]::SetText($output.Text);$status.Text='OUTPUT COPIED'}})

if($SelfTest){[pscustomobject]@{status='PASS';engine=$engine;control_count=$form.Controls.Count;decision_engine_count=1}|ConvertTo-Json;return}
[void]$form.ShowDialog()
