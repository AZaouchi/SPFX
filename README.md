# SPFX

## InfoPath XML to SharePoint list converter

Use `/home/runner/work/SPFX/SPFX/AZaouchi/SPFX/scripts/Convert-InfoPathXmlToSharePointList.ps1` to convert repeating InfoPath XML nodes into a CSV file that can be imported into a SharePoint list.

### Usage

```powershell
pwsh /home/runner/work/SPFX/SPFX/AZaouchi/SPFX/scripts/Convert-InfoPathXmlToSharePointList.ps1 \
  -InputXmlPath /path/to/form.xml \
  -OutputCsvPath /path/to/sharepoint-import.csv
```

If auto-detection does not pick the expected repeating row node, pass a specific XPath (with namespaces if required):

```powershell
pwsh /home/runner/work/SPFX/SPFX/AZaouchi/SPFX/scripts/Convert-InfoPathXmlToSharePointList.ps1 \
  -InputXmlPath /path/to/form.xml \
  -OutputCsvPath /path/to/sharepoint-import.csv \
  -RowXPath "//my:Item"
```
