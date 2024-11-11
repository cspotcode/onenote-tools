# Uses https://github.com/wightsci/OneNoteUtilities/
# Only works on Windows PowerShell, not PowerShellCore
# Installed via https://github.com/dfinke/InstallModuleFromGitHub / https://www.powershellgallery.com/packages/InstallModuleFromGitHub/1.6.0

$ErrorActionPreference = 'Stop'

Get-ONHierarchy

function iterate-pages($prefix, $sectionid) {
    $pageNames = @()
    foreach($page in (get-onpages -sectionid $sectionid)) {
        if($page.pageLevel -eq 1)
        {
            $pageNames = @($page.name)
        } else
        {
            # extend list
            while ($pageNames.Count -lt $page.pageLevel - 1)
            {
                $pageNames = $pageNames + ""
            }
            # truncate list
            $pageNames = $pageNames[0..($page.pageLevel - 2)] + $page.name
        }
        write-output ($prefix + " :: " + ($pageNames -join ' > '))
    }
}
foreach($notebook in (Get-ONNotebooks)) {
    foreach($section in (Get-ONSections -notebookid $notebook.id)) {
        iterate-pages ($notebook.name + " > " + $section.name) $section.id
    }
    foreach($sectiongroup in (Get-ONSectionGroups -notebookid $notebook.id)) {
        foreach($section in $sectiongroup.section)
        {
            iterate-pages ($notebook.name + " > " + $sectiongroup.name + " > " + $section.name) $section.id
        }
        #        foreach($section in (Get-ONSections -notebookname $notebook.name))
        #        {
        #
        #        }
    }
}