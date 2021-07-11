function disableButtons(disable) {
	document.querySelectorAll(".annotation-action").forEach((button) => {
		button.disabled = disable;
	});
}

window.addEventListener("WebComponentsReady", () => {
	const form = document.getElementById("edit-form");
	let selection = null;
	let activeSpan = null;
	const view = document.getElementById("view1");
	const occurDiv = document.getElementById("occurrences");
	const occurrences = occurDiv.querySelector("ul");
	const saveBtn = document.getElementById("form-save");
	const refInput = document.getElementById("form-ref");
	const authorityInfo = document.getElementById("authority-info");
	const authorityDialog = document.getElementById("authority-dialog");
	let autoSave = false;
	let type = "";
	let text = "";
	let enablePreview = true;

	/**
	 * Display the main form
	 *
	 * @param {string} type the annotation type
	 * @param {any} data properties of the annotation (if any); used to prefill the form
	 */
	function showForm(type, data) {
		form.reset();
		if (autoSave) {
			saveBtn.style.display = "none";
		} else {
			saveBtn.style.display = "";
		}
		form.style.display = "";
		form.querySelectorAll(`.annotation-form:not(.${type})`).forEach((elem) => {
			elem.style.display = "none";
		});
		form.querySelectorAll(`.annotation-form.${type}`).forEach((elem) => {
			elem.style.display = "";
		});
		occurDiv.style.display = "";
		occurrences.innerHTML = "";

		if (data) {
			Object.keys(data).forEach((key) => {
				const field = form.querySelector(`[name="${key}"]`);
				if (field) {
					field.value = data[key];
				}
			});
		}
	}

	function hideForm() {
		form.style.display = "none";
		occurDiv.style.display = "none";
	}

	/**
	 * The user selected an authority entry.
	 *
	 * @param {any} data details of the selected authority entry
	 */
	function authoritySelected(data) {
		authorityDialog.close();
		refInput.value = data.properties.ref;
		if (autoSave) {
			save();
		}
	}

	function selectOccurrence(data, o) {
		try {
			if (!o.annotated) {
				const teiRange = {
					type,
					properties: data,
					context: o.context,
					start: o.start,
					end: o.end,
					text: o.text,
				};
				return view.updateAnnotation(teiRange);
			} else if (data[view.key] !== o[view.key]) {
				view.editAnnotation(o.textNode.parentNode, data);
			} else {
				view.deleteAnnotation(o.textNode.parentNode);
			}
		} catch (e) {
			console.error(e);
			return false;
		}
	}

	/**
	 * Search the text for other potential occurrences of an authority entry
	 *
	 * @param {any} info details of the selected authority entry
	 */
	function findOther(info) {
		if (info) {
			strings = info.strings || [];
			strings.push(text);
		} else {
			strings = [text];
		}
		try {
			const occur = view.search(type, strings);
			occurrences.innerHTML = "";
			occur.forEach((o) => {
				const li = document.createElement("li");
				const cb = document.createElement("paper-checkbox");
				cb._options = o;
				cb._info = info;
				if (o.annotated && o[view.key] === info.id) {
					cb.setAttribute("checked", "checked");
				}
				cb.addEventListener("click", () => {
					const data = form.serializeForm();
					selectOccurrence(data, o);
					findOther(info);
				});

				li.appendChild(cb);
				const span = document.createElement("span");
				if (info.id && o[view.key] && o[view.key] !== info.id) {
					span.className = "id-warning";
				}
				span.innerHTML = o.kwic;
				li.appendChild(span);
				occurrences.appendChild(li);
				li.addEventListener("mouseenter", () => {
					view.scrollTo(o);
				});
				li.addEventListener("mouseleave", () => view.hideMarker());
			});
		} catch (e) {
			console.error(e);
		}
	}

	function save() {
		const data = form.serializeForm();
		// hideForm();
		if (activeSpan) {
			window.pbEvents.emit("pb-edit-annotation", "transcription", {
				target: activeSpan,
				properties: data,
			});
			activeSpan = null;
		} else {
			activeSpan = view.addAnnotation({
				type,
				properties: data,
			});
		}
	}

	/**
	 * Preview the current document with annotations merged in.
	 *
	 * @param {any} annotations the current list of annotations
	 */
	function preview(annotations, doStore) {
		const endpoint = document.querySelector("pb-page").getEndpoint();
		const doc = document.getElementById("document1");
		document.getElementById("json").innerText = JSON.stringify(annotations, null, 2);
		document.getElementById("output").code = "";
		fetch(`${endpoint}/api/annotations/merge/${doc.path}?${doStore ? "store=true" : ""}`, {
			method: "POST",
			mode: "cors",
			credentials: "same-origin",
			headers: {
				"Content-Type": "application/json",
			},
			body: JSON.stringify(annotations),
		})
			.then((response) => {
				if (response.ok) {
					return response.json();
				}
				throw new Error(response.status);
			})
			.then((json) => {
				if (doStore) {
					window.pbEvents.emit("pb-refresh", "transcription");
				}
				document.getElementById("output").code = json.content;
				const changeList = document.getElementById("changes");
				changeList.innerHTML = "";
				json.changes.forEach((change) => {
					const pre = document.createElement("pb-code-highlight");
					pre.setAttribute("language", "xml");
					pre.textContent = change;
					changeList.appendChild(pre);
				});
				fetch(
					`${endpoint}/api/preview?odd=${doc.odd}.odd&base=${encodeURIComponent(
						endpoint
					)}%2F`,
					{
						method: "POST",
						mode: "cors",
						credentials: "same-origin",
						headers: {
							"Content-Type": "application/xml",
						},
						body: json.content,
					}
				)
					.then((response) => response.text())
					.then((html) => {
						const iframe = document.getElementById("html");
						iframe.srcdoc = html;
					});
			});
	}

	function actionHandler(button) {
		if (selection) {
			type = button.getAttribute("data-type");
			if (button.classList.contains("toggle")) {
				save();
				return;
			}
			autoSave = false;
			if (button.classList.contains("authority")) {
				autoSave = true;
				window.pbEvents.emit("pb-authority-lookup", "transcription", {
					type,
					query: selection,
				});
				authorityDialog.open();
			}
			showForm(type);
			text = selection;
			activeSpan = null;
		}
		disableButtons(true);
	}

	function markAll(ev) {
		ev.preventDefault();
		ev.stopPropagation();
		window.pbEvents.emit("pb-start-update", "transcription", {});
		enablePreview = false;
		const data = form.serializeForm();
		const checkboxes = document.querySelectorAll(
			"#occurrences li paper-checkbox:not([checked])"
		);
		checkboxes.forEach((cb) => {
			cb.checked = selectOccurrence(data, cb._options) !== null;
		});
		findOther(checkboxes[0]._info);
		enablePreview = true;
		preview(view.annotations);
		window.pbEvents.emit("pb-end-update", "transcription", {});
	}

	hideForm();

	saveBtn.addEventListener("click", () => save());
	document
		.getElementById("reload-preview")
		.addEventListener("click", () => preview(view.annotations));
	document
		.getElementById("document-save")
		.addEventListener("click", () => preview(view.annotations, true));

	document.querySelector('#form-ref [slot="prefix"]').addEventListener("click", () => {
		window.pbEvents.emit("pb-authority-lookup", "transcription", {
			type,
			query: text,
		});
		authorityDialog.open();
	});
	/**
	 * Reference changed: update authority information and search for other occurrences
	 */
	refInput.addEventListener("value-changed", () => {
		const ref = refInput.value;
		if (ref && ref.length > 0) {
			authorityInfo.innerHTML = `Loading ${ref}...`;
			document
				.querySelector("pb-authority-lookup")
				.lookup(type, refInput.value, authorityInfo)
				.then(findOther)
				.catch(() => {
					authorityInfo.innerHTML = `Failed to load ${ref}`;
				});
		} else {
			authorityInfo.innerHTML = "";
		}
	});
	document.querySelectorAll(".annotation-action").forEach((button) => {
		const shortcut = button.getAttribute("data-shortcut");
		if (shortcut) {
			window.pbKeyboard(shortcut, (ev) => {
				ev.preventDefault();
				ev.stopPropagation();
				actionHandler(button);
			});
		}
		button.addEventListener("click", () => {
			actionHandler(button);
		});
	});
	window.pbEvents.subscribe("pb-authority-select", "transcription", (ev) =>
		authoritySelected(ev.detail)
	);
	window.pbEvents.subscribe("pb-selection-changed", "transcription", (ev) => {
		disableButtons(!ev.detail.hasContent);
		if (ev.detail.hasContent) {
			selection = ev.detail.range.cloneContents().textContent.replace(/\s+/g, " ");
		}
	});
	window.pbEvents.subscribe("pb-annotations-changed", "transcription", (ev) => {
		if (enablePreview) {
			preview(ev.detail.ranges);
		}
	});

	window.pbEvents.subscribe("pb-annotation-edit", "transcription", (ev) => {
		activeSpan = ev.detail.target;
		text = activeSpan.textContent.replace(/\s+/g, " ");
		type = ev.detail.type;
		autoSave = false;
		const trigger = document.querySelector(`[data-type=${type}]`);
		if (trigger && trigger.classList.contains("authority")) {
			autoSave = true;
			window.pbEvents.emit("pb-authority-lookup", "transcription", {
				type,
				query: text,
			});
			authorityDialog.open();
		}
		showForm(type, ev.detail.properties);
	});

	window.pbEvents.subscribe("pb-annotation-detail", "transcription", (ev) => {
		switch (ev.detail.type) {
			case "note":
				const data = JSON.parse(ev.detail.span.dataset.annotation);
				ev.detail.container.innerHTML = data.properties.note;
				break;
			case "date":
				break;
			default:
				document
					.querySelector("pb-authority-lookup")
					.lookup(ev.detail.type, ev.detail.id, ev.detail.container)
					.catch(() => {
						const div = document.createElement('div');
						const h = document.createElement('h3');
						h.innerHTML = 'Not found';
						div.appendChild(h);
						ev.detail.container.appendChild(h);
						const pre = document.createElement('pre');
						pre.className = 'error-notFound';
						const json = JSON.parse(ev.detail.span.dataset.annotation);
						pre.innerText = JSON.stringify(json.properties, null, 2);
						div.appendChild(pre);
						ev.detail.container.innerHTML = '';
						ev.detail.container.appendChild(div);
					});
				break;
		}
	});

	// const clearAll = document.getElementById("clear-all");
	// clearAll.addEventListener("click", () => window.pbEvents.emit("pb-refresh", "transcription"));

	const markAllBtn = document.getElementById("mark-all");
	window.pbKeyboard("command+option+a", markAll);
	markAllBtn.addEventListener("click", markAll);
});
