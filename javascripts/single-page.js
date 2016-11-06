
function lastModified() {
	if (document.lastModified) {
		document.getElementById('last-modified').innerHTML = "&nbsp;Last modified at " + new Date(document.lastModified).toLocaleString() + ".";
	}
}

function stickyHeader() {
	window.addEventListener('scroll', function(e) {
		var distanceY = window.pageYOffset || document.documentElement.scrollTop, shrinkOn = 40, header = document.querySelector("header");
		if (distanceY > shrinkOn) {
			classie.add(header, "smaller");
		} else {
			if (classie.has(header, "smaller")) {
				classie.remove(header, "smaller");
			}
		}
	});
}

function createToc() {
	tocbot.init({
		tocSelector: '.js-toc',
		contentSelector: '.main-content',
		headingSelector: 'h1, h2, h3',
		ignoreSelector: '.js-toc-ignore',
		collapseDepth: 1,
		smoothScrollOptions: {
		  easing: 'easeInOutCubic',
		  offset: 100,
		  speed: 300,
		  updateURL: true
		},
		headingsOffset: 100,
		positionFixedSelector: '.js-toc',
		fixedSidebarOffset: '-1',
	});
}

function initSinglePage() {
	lastModified();
	stickyHeader();
	createToc();
}

window.onload = initSinglePage();