[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputXmlPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputCsvPath,

    [string]$RowXPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NamespaceManager {
    param([xml]$Document)

    $nsManager = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    $namespaces = @{}

    foreach ($element in $Document.SelectNodes('//*')) {
        if ($null -eq $element.Attributes) {
            continue
        }

        foreach ($attribute in $element.Attributes) {
            if ($attribute.Prefix -eq 'xmlns' -and -not $namespaces.ContainsKey($attribute.LocalName)) {
                $namespaces[$attribute.LocalName] = $attribute.Value
            }
            elseif ($attribute.Name -eq 'xmlns' -and -not $namespaces.ContainsKey('d')) {
                $namespaces['d'] = $attribute.Value
            }
        }
    }

    foreach ($namespace in $namespaces.GetEnumerator()) {
        $nsManager.AddNamespace($namespace.Key, $namespace.Value)
    }

    return $nsManager
}

function Get-AutoDetectedRowNodes {
    param([xml]$Document)

    $candidates = @{}

    foreach ($node in $Document.SelectNodes('//*')) {
        $children = @($node.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
        if ($children.Count -eq 0) {
            continue
        }

        $containsNestedElements = $false
        foreach ($child in $children) {
            $grandChildren = @($child.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
            if ($grandChildren.Count -gt 0) {
                $containsNestedElements = $true
                break
            }
        }

        if ($containsNestedElements) {
            continue
        }

        $key = $node.LocalName
        if (-not $candidates.ContainsKey($key)) {
            $candidates[$key] = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
        }

        $null = $candidates[$key].Add($node)
    }

    if ($candidates.Count -eq 0) {
        throw 'No repeated row nodes were detected. Use -RowXPath to explicitly select the repeating XML node.'
    }

    $bestCandidate = $null
    foreach ($candidate in $candidates.GetEnumerator()) {
        if ($candidate.Value.Count -lt 2) {
            continue
        }

        if ($null -eq $bestCandidate -or $candidate.Value.Count -gt $bestCandidate.Value.Count) {
            $bestCandidate = $candidate
        }
    }

    if ($null -eq $bestCandidate) {
        throw 'No repeated row nodes were detected. Use -RowXPath to explicitly select the repeating XML node.'
    }

    return $bestCandidate.Value
}

function Convert-InfoPathXmlToRows {
    param(
        [xml]$Document,
        [string]$XPath
    )

    $rowNodes = @()

    if ([string]::IsNullOrWhiteSpace($XPath)) {
        $rowNodes = @(Get-AutoDetectedRowNodes -Document $Document)
    }
    else {
        $nsManager = Get-NamespaceManager -Document $Document
        $rowNodes = @($Document.SelectNodes($XPath, $nsManager))
        if ($rowNodes.Count -eq 0) {
            throw "XPath '$XPath' did not match any nodes in the XML input."
        }
    }

    $columnNames = New-Object System.Collections.Generic.List[string]
    $rows = New-Object System.Collections.Generic.List[hashtable]

    foreach ($rowNode in $rowNodes) {
        $row = @{}

        foreach ($child in @($rowNode.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })) {
            $nestedElements = @($child.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
            if ($nestedElements.Count -gt 0) {
                throw "Detected nested XML under '$($child.LocalName)'. Provide -RowXPath that targets a leaf row node."
            }

            $columnName = $child.LocalName
            if (-not $columnNames.Contains($columnName)) {
                $null = $columnNames.Add($columnName)
            }

            $row[$columnName] = $child.InnerText.Trim()
        }

        $null = $rows.Add($row)
    }

    $outputRows = foreach ($row in $rows) {
        $outputRow = [ordered]@{}
        foreach ($columnName in $columnNames) {
            $outputRow[$columnName] = if ($row.ContainsKey($columnName)) { $row[$columnName] } else { '' }
        }

        [pscustomobject]$outputRow
    }

    return $outputRows
}

if (-not (Test-Path -LiteralPath $InputXmlPath)) {
    throw "Input XML file was not found: $InputXmlPath"
}

[xml]$xmlDocument = Get-Content -LiteralPath $InputXmlPath -Raw
$csvRows = Convert-InfoPathXmlToRows -Document $xmlDocument -XPath $RowXPath

$outputDirectory = Split-Path -Parent $OutputCsvPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}

$csvRows | Export-Csv -LiteralPath $OutputCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Converted $($csvRows.Count) rows to '$OutputCsvPath'."
