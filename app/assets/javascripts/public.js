// namespace (our namespace name) and undefined are passed here
// to ensure 1. namespace can be modified locally and isn't
// overwritten outside of our function context
// 2. the value of undefined is guaranteed as being truly
// undefined. This is to avoid issues with undefined being
// mutable pre-ES5.

;
(function (baw, undefined) {
    // private properties - globals, formatters, magic numbers
    var day = null,
        week = null,
        format = null,
        month_format = null,
        width = 960,
        height = 136,
        cellSize = 17, // cell size
        minYear = 2007,
        firstYear = null, //new Date().getFullYear(),
        lastYear = null, //2007
        colourDomain = [0, 100],//domain is input values, usually x
        colourRangeStart = 0, // range is output values, usually y
        colourRangeStop = 10,
        colourRangeStep = 1,
        defaultSelection = [
            {name: '-- Everything --', id: null}
        ];

    // public methods and properties
//    namespace.foobar = "foobar";
//    namespace.sayHello = function () {
//        speak("hello world");
//    };
    baw.begin = function begin() {

        day = d3.time.format("%w");
        week = d3.time.format("%U");
        format = d3.time.format("%Y-%m-%d");
        month_format = d3.time.format("%b");

        getProjectList(function (error, json) {
            updateProjectList(error, json);

            var projectId = getQueryStringProjectId();
            selectValueInProjectList(projectId);

            getSiteList(projectId, function (error, json) {
                updateSiteList(error, json);

                var siteId = getQueryStringSiteId();
                selectValueInSiteList(siteId);
            });

        });

        setButtonClick();

        updateCatalogueData();

        setCalendarProperties();
    };

    // private methods

    function setCalendarProperties() {
        d3.select('#audioRecordingCalendar').style("height", "1100px");
    }

    function createUrl() {
        var projectId = getSelectedProject();
        var siteId = getSelectedSite();
        var url = window.location.origin + window.location.pathname + '?' + createUrlQueryString(projectId, siteId);
        return url;
    }

    function createUrlQueryString(projectId, siteId) {
        var url = '';

        if (projectId != null) {
            url += 'projectId=' + projectId;
        }


        if (siteId != null) {
            url += '&siteId=' + siteId;
        }

        return url;
    }

    function getSiteList(projectId, callback) {
        var url = "/projects/" + projectId + "/sites.json";
        d3.json(url, function (error, json) {
            if(error != null){
                console.warn('getSiteList', error);
            }
            if (callback != null) {
                callback(error, json);
            }

        });
    }

    function updateSiteList(error, json) {
        d3.select('#site_list')
            .selectAll('option')
            .remove()
            .data(defaultSelection.concat(json))
            .enter()
            .append('option')
            .attr('value', function (d) {
                return d.id
            })
            .text(function (d) {
                return d.name;
            });
    }

    function getProjectList(callback) {
        d3.json("/projects.json", function (error, json) {
            if(error != null){
                console.warn('getProjectList', error);
            }
            if (callback != null) {
                callback(error, json);
            }
        });
    }

    function updateProjectList(error, json) {
        d3.select('#project_list')
            .on('change', updateSiteListFromProject)
            .selectAll('option')
            .data(defaultSelection.concat(json))
            .enter()
            .append('option')
            .attr('value', function (d) {
                return d.id
            })
            .text(function (d) {
                return d.name;
            });
    }

    function updateSiteListFromProject() {
        var selectedValue = getSelectedProject();
        if (selectedValue != null) {
            getSiteList(selectedValue, function (error, json) {
                updateSiteList(error, json);
            });
        } else {
            d3.select('#site_list')
                .selectAll('option')
                .remove();
        }
    }

    function getSelectedProject() {
        return getSelectedValue('project_list');
    }

    function getSelectedSite() {
        return getSelectedValue('site_list');
    }

    function getSelectedValue(elementId) {
        var element = document.getElementById(elementId);
        var selectedIndex = element.selectedIndex;

        if (selectedIndex > 0) {
            return element.options[selectedIndex].value;
        } else {
            return null;
        }
    }

    function selectValueInProjectList(value) {
        if (value != null) {
            document.getElementById('project_list').value = parseInt(value);
        }
    }

    function selectValueInSiteList(value) {
        if (value != null) {
            document.getElementById('site_list').value = parseInt(value);
        }
    }

    function getQueryStringProjectId() {
        return $.getUrlVar('projectId');
    }

    function getQueryStringSiteId() {
        return $.getUrlVar('siteId');
    }

    function addDataToCalendar(rect, data) {
        rect
            .filter(function (d) {
                return d in data;
            })
            .attr("class", function (d) {
                return "day " + (data[d] > 0 ? 'q9-11' : '');
            })
            .select("title")
            .text(function (d) {
                return d + ": " + data[d] + " audio recordings";
            });
    }

    function getCatalogueData(callback) {
        var projectId = getQueryStringProjectId();
        var siteId = getQueryStringSiteId();
        var url = "/audio_recording_catalogue.json?" + createUrlQueryString(projectId, siteId);
        d3.json(url, function (error, json) {
            if(error != null){
                console.warn('getCatalogueData', error);
            }
            if (callback != null) {
                callback(error, json);
            }
        });
    }

    function updateCatalogueData() {
        getCatalogueData(function (error, json) {
            var data = d3.nest()
                .key(function (d) {
                    return d.extracted_year + "-" + d.extracted_month + "-" + d.extracted_day;
                })
                .rollup(function (d) {
                    var itemYear = parseInt(d[0].extracted_year);
                    if (firstYear == null || itemYear > firstYear) {
                        firstYear = itemYear;
                    }
                    if (lastYear == null || itemYear < lastYear) {
                        lastYear = itemYear;
                    }

                    var itemCount = parseInt(d[0].count);
                    if (colourRangeStop == null || itemCount > colourRangeStop) {
                        colourRangeStop = itemCount;
                    }

                    return itemCount;
                })
                .map(json);

            // ensure year doesn't go beyond 2007
            if (lastYear < minYear) {
                lastYear = minYear;
            }

            var elements = createSvgCalendarView(firstYear, lastYear);
            addDataToCalendar(elements.rect, data)
        });
    }

    function setButtonClick() {
        d3.select('#update_calendar')
            .on('click', function () {
                window.location = createUrl();
            });
    }

    function createSvgCalendarView(firstYear, lastYear) {

        // create svg and year rows
        var svg = d3.select("#audioRecordingCalendar").selectAll("svg")
            .data(d3.range(firstYear, lastYear - 1, -1)) // subtract one due to exclusive end bound
            .enter().append("svg")
            .attr("width", width)
            .attr("height", height)
            .attr("class", "RdYlGn")
            .append("g")
            .attr("transform", "translate(" + ((width - cellSize * 53) / 2) + "," + (height - cellSize * 7 - 1) + ")");

        // add year label to left end
        svg.append("text")
            .attr("transform", "translate(-6," + cellSize * 3.5 + ")rotate(-90)")
            .style("text-anchor", "middle")
            .text(function (d) {
                return d;
            });

        // create day rectangles
        var rect = svg.selectAll(".day")
            .data(function (d) {
                return d3.time.days(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter().append("rect")
            .attr("class", "day")
            .attr("width", cellSize)
            .attr("height", cellSize)
            .attr("x", function (d) {
                return week(d) * cellSize;
            })
            .attr("y", function (d) {
                return day(d) * cellSize;
            })
            .datum(format);

        // add titles to day rectangles
        rect.append("title")
            .text(function (d) {
                return d;
            });

        // find the months and outline them
        var month = svg.selectAll(".month")
            .data(function (d) {
                return d3.time.months(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter().append("path")
            .attr("class", "month")
            .attr("d", monthPath);

        // add labels for each month
        svg.selectAll(".monthText")
            .data(function (d) {
                return d3.time.months(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter()
            .append("text")
            .attr("x", function (d) {
                return (week(d) * cellSize) + (cellSize * 2.8);
            })
            .attr("y", function (d) {
                return -2.5;
            })
            .style("text-anchor", "middle")
            .text(function (d) {
                return month_format(d);
            });

        return {
            svg: svg,
            day: day,
            month: month,
            rect: rect
        };
    }

    // calculate the path to surround the days of the month
    function monthPath(t0) {
        var t1 = new Date(t0.getFullYear(), t0.getMonth() + 1, 0),
            d0 = +day(t0), w0 = +week(t0),
            d1 = +day(t1), w1 = +week(t1);
        return "M" + (w0 + 1) * cellSize + "," + d0 * cellSize
            + "H" + w0 * cellSize + "V" + 7 * cellSize
            + "H" + w1 * cellSize + "V" + (d1 + 1) * cellSize
            + "H" + (w1 + 1) * cellSize + "V" + 0
            + "H" + (w0 + 1) * cellSize + "Z";
    }

    // check to evaluate whether 'namespace' exists in the
    // global namespace - if not, assign window.namespace an
    // object literal
})(window.baw = window.baw || {});

// we can then test our properties and methods as follows

// public
//console.log(namespace.foobar); // foobar
//namescpace.sayHello(); // hello world

// assigning new properties
//namespace.foobar2 = "foobar";
//console.log(namespace.foobar2);