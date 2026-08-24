param([Parameter(Mandatory=$true)][string]$Root,[switch]$SelfTest,[string]$E2EInput)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$engine=Join-Path $Root 'TOOL006_TOC\tool006_engine.ps1'
if(-not(Test-Path -LiteralPath $engine -PathType Leaf)){throw "TOOL006 engine not found: $engine"}

$form=New-Object Windows.Forms.Form
$form.Text='TOOL006 TOC Organizer';$form.Width=1240;$form.Height=820;$form.StartPosition='CenterScreen'
$inputBox=New-Object Windows.Forms.TextBox;$inputBox.Multiline=$true;$inputBox.ScrollBars='Both';$inputBox.WordWrap=$false;$inputBox.SetBounds(20,90,570,560)
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
$form.Controls.AddRange(@($inputBox,$output,$run,$clear,$copy,$publisher,$report,$errorType,$corrected,$status,$leftLabel,$rightLabel,$fixLabel))

$executeEngine={
    try{
        $uiInputPath=Join-Path $Root 'TOOL006_TOC\working\ui_input.txt'
        New-Item -ItemType Directory -Path (Split-Path $uiInputPath) -Force|Out-Null
        $inputBox.Text|Set-Content -LiteralPath $uiInputPath -Encoding UTF8
        $args=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$engine,'-Root',$Root,'-InputPath',$uiInputPath,'-Publisher',$publisher.Text,'-ReportId',$report.Text)
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
    }catch{$status.Text='ERROR: '+$_.Exception.Message}
}
$run.Add_Click($executeEngine)
$clear.Add_Click({$inputBox.Clear();$output.Clear();$corrected.Clear();$status.Text='READY'})
$copy.Add_Click({if($output.Text){[Windows.Forms.Clipboard]::SetText($output.Text);$status.Text='OUTPUT COPIED'}})

if($SelfTest){[pscustomobject]@{status='PASS';engine=$engine;control_count=$form.Controls.Count;decision_engine_count=1}|ConvertTo-Json;return}
if($E2EInput){
    $inputBox.Text=$E2EInput
    &$executeEngine
    if($status.Text -like 'ERROR:*'){throw $status.Text}
    $state=Get-Content -LiteralPath (Join-Path $Root 'TOOL006_TOC\tool_state.json') -Raw -Encoding UTF8|ConvertFrom-Json
    [pscustomobject]@{status='PASS';ui_status=$status.Text;engine_status=$state.FINAL_STATUS;output_path=$state.OUTPUT_PATH;output=$output.Text;decision_engine_count=1}|ConvertTo-Json -Depth 4
    return
}
[void]$form.ShowDialog()
