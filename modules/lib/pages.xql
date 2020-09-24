(:
 :
 :  Copyright (C) 2015 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

(:~
 : Template functions to handle page by page navigation and display
 : pages using TEI Simple.
 :)
module namespace pages="http://www.tei-c.org/tei-simple/pages";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace expath="http://expath.org/ns/pkg";

import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../navigation.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "../query.xql";
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";

declare variable $pages:EXIDE :=
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");

declare variable $pages:EDIT_ODD_LINK :=
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://existsolutions.com/apps/tei-publisher"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "odd-editor.html"), "/")
    return
        replace($path, "/+", "/");

declare function pages:pb-document($node as node(), $model as map(*)) {
    let $odd := ($node/@odd, $model?odd) [1]
    let $data := config:get-document($model?doc)
    let $config := tpu:parse-pi(root($data), $model?view, $odd)
    return
        <pb-document path="{$model?doc}" root-path="{$config:data-root}" view="{$config?view}" odd="{replace($config?odd, '^(.*)\.odd', '$1')}"
            source-view="{$pages:EXIDE}">
            { $node/@id }
        </pb-document>
};

declare
    %templates:wrap
function pages:pb-markdown($node as node(), $model as map(*), $doc as xs:string) {
    attribute url  {
        "raw/" || $doc
    }
};

(:~
 : Generate the actual script tag to import pb-components.
 :)
declare function pages:load-components($node as node(), $model as map(*)) {
    if (not($node/preceding::script[@data-template="pages:load-components"])) then (
        <script src="https://unpkg.com/@webcomponents/webcomponentsjs@2.4.3/webcomponents-loader.js"></script>,
        <script src="https://unpkg.com/web-animations-js@2.3.2/web-animations-next-lite.min.js"></script>
    ) else
        (),
    switch ($config:webcomponents)
        case "local" return
            <script type="module" src="resources/scripts/{$node/@src}"></script>
        case "dev" return
            <script type="module" 
                src="{$config:webcomponents-cdn}/src/{$node/@src}"></script>
        default return
            <script type="module" 
                src="{$config:webcomponents-cdn}@{$config:webcomponents}/dist/{$node/@src}"></script>
};

declare function pages:current-language($node as node(), $model as map(*), $lang as xs:string?) {
    element { node-name($node) } {
        $node/@*,
        attribute selected { $lang },
        $node/*
    }
};

declare function pages:load-xml($view as xs:string?, $root as xs:string?, $doc as xs:string) {
    for $data in config:get-document($doc)
    return
        if (exists($data)) then
            pages:load-xml($data, $view, $root, $doc)
        else
            ()
};

declare function pages:load-xml($data as node()*, $view as xs:string?, $root as xs:string?, $doc as xs:string) {
    let $config :=
        (: parse processing instructions and remember original context :)
        map:merge((tpu:parse-pi(root($data[1]), $view), map { "context": $data }))
    return
        map {
            "config": $config,
            "data":
                switch ($config?view)
            	    case "div" return
                        if ($root) then
                            let $node := util:node-by-id($data, $root)
                            return
                                nav:get-section-for-node($config, $node)
                        else
                            nav:get-section($config, $data)
                    case "page" return
                        if ($root) then
                            util:node-by-id($data, $root)
                        else
                            nav:get-first-page-start($config, $data)
                    case "single" return
                        if ($root) then
                            util:node-by-id($data, $root)
                        else
                            $data
                    default return
                        if ($root) then
                            util:node-by-id($data, $root)
                        else
                            $data/tei:TEI/tei:text
        }
};

declare function pages:edit-odd-link($node as node(), $model as map(*)) {
    <pb-download url="{$pages:EDIT_ODD_LINK}" source="source"
        params="root={$config:odd-root}&amp;output-root={$config:output-root}&amp;output={$config:output}">
        {$node/@*, $node/node()}
    </pb-download>
};

(:~
 : Only used for generated app: output edit link for every registered ODD
 :)
declare function pages:edit-odd-list($node as node(), $model as map(*)) {
    for $odd in $config:odd-available
    return
        <paper-item>
            <a href="{$pages:EDIT_ODD_LINK}?root={$config:odd-root}&amp;output-root={$config:output-root}&amp;output={$config:output}&amp;odd={$odd}"
                target="_blank">
                <pb-i18n key="menu.admin.edit-odd">Edit ODD</pb-i18n>: {$odd}
            </a>
        </paper-item>
};

declare function pages:process-content($xml as node()*, $root as node()*, $config as map(*)) {
    pages:process-content($xml, $root, $config, ())
};

declare function pages:process-content($xml as node()*, $root as node()*, $config as map(*), $userParams as map(*)?) {
    let $params := map:merge((
            map {
                "root": $root,
                "view": $config?view
            },
            $userParams))
	let $html := $pm-config:web-transform($xml, $params, $config?odd)
    let $class := if ($html//*[@class = ('margin-note')]) then "margin-right" else ()
    let $body := pages:clean-footnotes($html)
    return
        <div class="{$config:css-content-class} {$class}">
        {
            $body,
            if ($html//*[@class="footnote"]) then
                nav:output-footnotes($html//*[@class = "footnote"])
            else
                ()
            ,
            $html//paper-tooltip
        }
        </div>
};

declare function pages:clean-footnotes($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(paper-tooltip) return
		()
            case element() return
                if ($node/@class = "footnote") then
                    ()
                else
                    element { node-name($node) } {
                        $node/@*,
                        pages:clean-footnotes($node/node())
                    }
            default return
                $node
};
declare function pages:toc-div($node, $model as map(*), $target as xs:string?,
    $icons as xs:boolean?) {
    let $view := $model?config?view
    let $divs := nav:get-subsections($model?config, $node)
    return
        <ul>
        {
            for $div in $divs
            let $headings := nav:get-section-heading($model?config, $div)/node()
            let $html :=
                if ($headings/*) then
                    $pm-config:web-transform($headings, map { "mode": "toc", "root": $div }, $model?config?odd)
                else
                    $headings/string()
            let $root := (
                if ($view = "page") then
                    ($div/*[1][self::tei:pb], $div/preceding::tei:pb[1])[1]
                else
                    (),
                $div
            )[1]
            let $parent := nav:is-filler($model?config, $div)
            let $hasDivs := exists(nav:get-subsections($model?config, $div))
            let $nodeId :=  if ($parent) then util:node-id($parent) else util:node-id($root)
            let $subsect := if ($parent) then attribute hash { util:node-id($root) } else ()
            return
                    <li>
                    {
                        if ($hasDivs) then
                            <pb-collapse>
                                {
                                    if (not($icons)) then
                                        attribute no-icons { "no-icons" }
                                    else
                                        ()
                                }
                                <span slot="collapse-trigger">
                                    <pb-link node-id="{$nodeId}" emit="{$target}" subscribe="{$target}">{$subsect, $html}</pb-link>
                                </span>
                                <span slot="collapse-content">
                                { pages:toc-div($div, $model, $target, $icons) }
                                </span>
                            </pb-collapse>
                        else
                            <pb-link node-id="{$nodeId}" emit="{$target}" subscribe="{$target}">{$subsect, $html}</pb-link>
                    }
                    </li>
        }
        </ul>
};

declare function pages:get-content($config as map(*), $div as element()) {
    nav:get-content($config, $div)
};

declare function pages:pb-page($node as node(), $model as map(*)) {
    let $model := map:merge(
        (
            $model,
            map { "app": $config:context-path }
        )
    )
    return
        element { node-name($node) } {
            $node/@*,
            attribute app-root { $config:context-path },
            attribute template { $model?template },
            attribute endpoint { $config:context-path },
            templates:process($node/*, $model)
        }
};

declare function pages:determine-view($view as xs:string?, $node as node()) {
    typeswitch ($node)
        case element(tei:body) return
            "body"
        case element(tei:front) return
            "body"
        case element(tei:back) return
            "body"
        default return
            if ($view) then $view else $config:default-view
};

declare function pages:switch-view($node as node(), $model as map(*), $root as xs:string?, $doc as xs:string, $view as xs:string?) {
    let $view := pages:determine-view($view, $model?data)
    let $targetView := if ($view = "page") then "div" else "page"
    let $root := pages:switch-view-id($model?data, $view)
    return
        element { node-name($node) } {
            $node/@* except $node/@class,
            if (pages:has-pages($model?data)) then (
                attribute href {
                    "?root=" ||
                    (if (empty($root) or $root instance of element(tei:body) or $root instance of element(tei:front)) then () else util:node-id($root)) ||
                    "&amp;odd=" || $model?config?odd || "&amp;view=" || $targetView
                },
                if ($view = "page") then (
                    attribute aria-pressed { "true" },
                    attribute class { $node/@class || " active" }
                ) else
                    $node/@class
            ) else (
                $node/@class,
                attribute disabled { "disabled" }
            ),
            templates:process($node/node(), $model)
        }
};

declare function pages:has-pages($data as element()+) {
    exists(root($data)//tei:pb)
};

declare function pages:switch-view-id($data as element()+, $view as xs:string) {
    let $root :=
        if ($view = "div") then
            ($data/*[1][self::tei:pb], $data/preceding::tei:pb[1])[1]
        else
            ($data/ancestor::tei:div, $data/following::tei:div, $data/ancestor::tei:body, $data/ancestor::tei:front)[1]
    return
        $root
};

declare function pages:parse-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        for $attr in $node/@*
        return
            if (matches($attr, "\$\{[^\}]+\}")) then
                attribute { node-name($attr) } {
                    string-join(
                        let $parsed := analyze-string($attr, "\$\{([^\}]+?)(?::([^\}]+))?\}")
                        for $token in $parsed/node()
                        return
                            typeswitch($token)
                                case element(fn:non-match) return $token/string()
                                case element(fn:match) return
                                    let $paramName := $token/fn:group[1]/string()
                                    let $default := $token/fn:group[2]/string()
                                    let $found := [
                                        request:get-parameter($paramName, $default),
                                        $model($paramName),
                                        session:get-attribute($config:session-prefix || "." || $paramName)
                                    ]
                                    return
                                        array:fold-right($found, (), function($in, $value) {
                                            if (exists($in)) then $in else $value
                                        })
                                default return $token
                    )
                }
            else
                $attr,
        templates:process($node/node(), $model)
    }
};

declare 
    %templates:wrap
function pages:languages($node as node(), $model as map(*)) {
    let $json := json-doc($config:app-root || "/resources/i18n/languages.json")
    return
        map:for-each($json, function($key, $value) {
            <paper-item value="{$key}">{$value}</paper-item>
        })
};

declare 
    %templates:wrap
function pages:version($node as node(), $model as map(*)) {
    $config:expath-descriptor/@version/string()
};

declare 
    %templates:wrap
function pages:error-description($node as node(), $model as map(*)) {
    $model?description
};