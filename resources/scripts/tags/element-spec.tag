<element-spec ident="{ ident }" mode="{ mode }">
    <h3>
        <a href="#elem-{ ident }" data-toggle="collapse"><span ref="toggle" class="material-icons"
            if="{ models.length > 0 }">expand_more</span></a>
        { ident }
        <div class="btn-group">
            <button type="button" class="btn btn-xs dropdown-toggle" data-toggle="dropdown"><i class="material-icons">add</i></button>
            <ul class="dropdown-menu">
                <li><a href="#" onclick="{ addModel }">model</a></li>
                <li><a href="#" onclick="{ addModel }">modelSequence</a></li>
                <li><a href="#" onclick="{ addModel }">modelGrp</a></li>
            </ul>
        </div>
        <button type="button" class="btn btn-xs" onclick="{ remove }"><i class="material-icons">delete</i></button>
        <button type="button" class="btn btn-default btn-xs" onclick="{ paste }">
            <i class="material-icons">content_paste</i>
        </button>
    </h3>

    <div ref="models" id="elem-{ ident }" class="collapse models {show ? 'in' : ''}">
        <model each="{ models }" behaviour="{ this.behaviour }" predicate="{ this.predicate }"
            type="{ this.type }" output="{ this.output }" css="{ this.css }" models="{ this.models }"
            parameters="{ this.parameters }" desc="{ this.desc }"
            sourcerend="{ this.sourcerend }"/>
    </div>

    <script>
        this.mixin('utils');

        this.on("mount", function() {
            var self = this;
            $(this.refs.models).on("show.bs.collapse", function() {
                $(self.refs.toggle).text("expand_less");
            });
            $(this.refs.models).on("shown.bs.collapse", function() {
                self.app.trigger('show');
            });
            $(this.refs.models).on("hide.bs.collapse", function() {
                $(self.refs.toggle).text("expand_more");
            });
        });

        addModel(ev) {
            ev.preventDefault();
            var type = $(ev.target).text();

            this.models = this.updateTag('model');

            $(this.refs.models).collapse("show");
            this.models.unshift({
                behaviour: 'inline',
                predicate: null,
                type: type,
                output: null,
                models: [],
                parameters: [],
                renditions: [],
                sourcerend: false,
                show: true
            });
        }

        removeModel(item) {
            this.parent.refs.dialog.confirm('Delete?', 'Are you sure to delete the model?')
                .then(function() {
                    var index = this.models.indexOf(item);
                    this.models = this.updateTag('model');
                    this.models.splice(index, 1);

                    this.update();
                }.bind(this)
            );
        }

        remove(ev) {
            this.parent.removeElementSpec(ev.item);
        }

        paste(ev) {
            var data = this.clipboard.paste();
            if (data) {
                this.models = this.updateTag('model');
                $(this.refs.models).collapse("show");
                this.models.unshift(data);
            }
        }

        getData() {
            return {
                ident: this.ident,
                mode: this.mode,
                models: this.updateTag('model')
            };
        }

        serialize(indent) {
            var xml = indent + '<elementSpec ident="' + this.ident + '"';
            if (this.mode) {
                xml += ' mode="' + this.mode + '"';
            }
            xml += '>\n';

            xml += this.serializeTag('model', indent + this.indentString);

            xml += indent + '</elementSpec>\n';
            return xml;
        }
    </script>

    <style>
        input { vertical-align: middle; }
    </style>
</element-spec>