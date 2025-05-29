import { parseArgs } from "jsr:@std/cli/parse-args";
import { render } from "jsr:@deno/gfm";

// Deno script renders markdown to html
// includes styles to make the markdown look nice, perhaps like github style

const flags = parseArgs(Deno.args, {
    boolean: ["help", "watch", "light"],
    string: ["output"],
    alias: { h: "help", w: "watch", o: "output" },
});

if (flags.help) {
    console.log("Usage: md-to-html.ts [--watch] [--output=<file>] <markdown-file>");
    Deno.exit(0);
}

const inputFile = flags._[0]?.toString();
if (!inputFile) {
    console.error("Error: Input file is required");
    Deno.exit(1);
}

const outputFile = flags.output || inputFile.replace(/\.md$/, ".html");

async function processFile() {
    try {
        const markdown = await Deno.readTextFile(inputFile);
        const html = render(markdown, {
            allowIframes: true,
            disableHtmlSanitization: false,
        });

        const useLight = flags.light ?? false;
        const theme = useLight ? 'light' : 'dark';
        
        const fullHtml = `
    <!DOCTYPE html>
    <html data-color-mode="${theme}" data-${theme}-theme="${theme}">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Markdown Preview</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.1.0/github-markdown-${theme}.min.css">
        <style>
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 45px;
        }

        @media (max-width: 767px) {
            .markdown-body {
            padding: 15px;
            }
        }
        </style>
    </head>
    <body>
        <article class="markdown-body">
        ${html}
        </article>
    </body>
    </html>
        `.trim();

        await Deno.writeTextFile(outputFile, fullHtml);
        console.log(`Rendered ${inputFile} to ${outputFile}`);
    } catch (error) {
        console.error("Error:", (error as Error).message);
        Deno.exit(1);
    }
}

if (flags.watch) {
    console.log(`Watching ${inputFile} for changes...`);
    await processFile();
    
    const watcher = Deno.watchFs(inputFile);
    for await (const event of watcher) {
        if (event.kind === "modify") {
            console.log(`${inputFile} changed, reprocessing...`);
            await processFile();
        }
    }
} else {
    await processFile();
}