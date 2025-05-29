# Uses https://github.com/wightsci/OneNoteUtilities/
# Only works on Windows PowerShell, not PowerShellCore
# Installed via https://github.com/dfinke/InstallModuleFromGitHub / https://www.powershellgallery.com/packages/InstallModuleFromGitHub/1.6.0

$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

Get-ONHierarchy

# Hack because class methods can't write to output stream.
class Stream {
    [System.Collections.ArrayList]$values
    Stream() {
        $this.clear()
    }
    write($value) {
        $this.values.Add($value)
    }
    clear() {
        $this.values = @()
    }
}

class Walker {
    $notebook = $null
    [string]$notebookName = ""
    $sectionGroup = $null
    $section = $null
    $page = $null
    [string[]]$pagePath = @()

    [Logger]$logger

    walk() {
        # For each notebook
        foreach($notebook in (Get-ONNotebooks)) {
            $this.notebook = $notebook
            $this.notebookName = $notebook.nickname
            if ($notebook.nickname -ne $notebook.name) {
                $this.notebookName = $notebook.nickname + " (" + $notebook.name + ")"
            }
            $this.logger.logNotebook()

            # For each section in the notebook
            $this.sectionGroup = $null
            foreach($section in (Get-ONSections -notebookid $notebook.id)) {
                $this.section = $section
                $this.logger.logSection()
                $this.iteratePages()
            }

            # For each section group in the notebook
            foreach($sectiongroup in (Get-ONSectionGroups -notebookid $notebook.id)) {
                $this.sectionGroup = $sectionGroup
                $this.logger.logSectionGroup()

                # For each section in the section group
                foreach($section in $sectiongroup.section) {
                    $this.section = $section
                    $this.logger.logSection()
                    $this.iteratePages()
                }
            }
        }
    }
    iteratePages() {
        $this.pagePath = @()
        foreach($page in (get-onpages -sectionid $this.section.Id)) {
            $this.page = $page
            # Fully outdented page, reset the list
            if($page.pageLevel -eq 1) {
                $this.pagePath = @($page.name)
            } else {
                $lastPageIndent = $this.pagePath.Count
                $pageLevel = $page.pageLevel
                if ($lastPageIndent -lt $page.pageLevel -and $lastPageIndent + 1 -ne $pageLevel) {
                    write-host "Page indent jumped unexpectedly from $($lastPageIndent + 1) to $($pageLevel)"
                    exit 1
                }

                # Extend list to sufficient length by adding empty strings
                while ($this.pagePath.Count -lt $page.pageLevel - 1) {
                    $this.pagePath = $this.pagePath + ""
                }
                # truncate list to correct length, append page name
                $this.pagePath = $this.pagePath[0..($page.pageLevel - 2)] + $page.name
            }

            $this.logger.logPage()
        }
        $this.logger.logEndOfPages()
    }
}

class Logger {
    Logger($walker, $stream) {
        $this.walker = $walker
        $this.stream = $stream
    }
    [Walker]$walker
    [Stream]$stream
    logNotebook() {}
    logSectionGroup() {}
    logSection() {}
    logPage() {}
    logEndOfPages() {}
}

class BasicLogger : Logger {
    BasicLogger($walker, $stream) : base($walker, $stream) {}
    [string]$prefix = ""
    logSection() {
        if ($null -ne $this.walker.sectionGroup) {
            $this.prefix = $this.walker.notebookName + " > " + $this.walker.sectionGroup.name + " > " + $this.walker.section.name
        } else {
            $this.prefix = $this.walker.notebookName + " > " + $this.walker.section.name
        }
    }
    logPage() {
        $this.stream.write($this.prefix + " :: " + ($this.walker.pagePath -join  " > "))
    }
}

class MarkdownLogger : Logger {
    MarkdownLogger($walker, $stream) : base($walker, $stream) {}
    logNotebook() {
        $this.stream.write("# " + $this.walker.notebookName)
        $this.stream.write("")
    }
    logSectionGroup() {
        $this.stream.write("## " + $this.walker.sectionGroup.name)
        $this.stream.write("")
    }
    logSection() {
        if($null -eq $this.walker.sectionGroup) {
            $heading = "## "
        } else {
            $heading =  "### "
        }
        $this.stream.write($heading + $this.walker.section.name)
        $this.stream.write("")
    }
    logPage() {
        $indent = "  " * ($this.walker.page.pageLevel - 1)
        $this.stream.write($indent + "* " + $this.walker.page.name)
    }
    logEndOfPages() {
        $this.stream.write("")
    }
}

$walker = [Walker]::new()

# Text output
$logger = [BasicLogger]::new($walker, [Stream]::new())
$walker.logger = $logger
$walker.walk()
[IO.File]::WriteAllText((Join-Path (get-location) 'output.txt'), $logger.stream.values -join "`n")

# Markdown output
$logger = [MarkdownLogger]::new($walker, [Stream]::new())
$walker.logger = $logger
$walker.walk()
[IO.File]::WriteAllText((Join-Path (get-location) 'output.md'), $logger.stream.values -join "`n")

# Html output
deno -A $PSScriptRoot/../md-to-html/md-to-html.ts --output=output.html --light ./output.md
