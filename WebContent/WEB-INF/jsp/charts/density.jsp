<%--
		GIGWA - Genotype Investigator for Genome Wide Analyses
		Copyright (C) 2016 <CIRAD>
		    
		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU Affero General Public License, version 3 as
		published by the Free Software Foundation.
		
		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU Affero General Public License for more details.
		
		See <http://www.gnu.org/licenses/gpl-3.0.html> for details about
		GNU Affero General Public License V3.
--%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<%@ page language="java" import="fr.cirad.web.controller.gigwa.base.AbstractVariantController"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
<html lang="en">
<head>
    <title>Variant density chart</title>
    <meta charset="UTF-8">
    <link rel="stylesheet" type="text/css" href="../css/main.css" title="style">
	<script type="text/javascript" src="../js/jquery-1.8.2.min.js"></script>
<!-- 	<script type="text/javascript" src="../js/jquery.simplemodal.1.4.4_removeExpression_fixed.js"></script> -->
	<script src="../js/highcharts.js"></script>
	<script src="../js/exporting.js"></script>
</head>

<body style="background-color:#ffffff;">

<div id="chartContainer" style="min-width:310px; height:370px; margin:0 auto; overflow:hidden;"></div>

<script type="text/javascript">
var minimumProcessQueryIntervalUnit = 500;
var currentDensityProcessID = null;
var chart = null;
var displayedRangeIntervalCount = 400;

$.getJSON('<c:url value="<%= AbstractVariantController.distinctSequencesInSelectionURL %>" />?module=${param.module}&project=${param.project}&processID=' + encodeURIComponent('${param.processID}'), {}, function(jsonResult){
	feedSequenceSelectAndLoadVariantTypeList(jsonResult);
}).error(function(xhr, ajaxOptions, thrownError) {
 	alert(thrownError);
});

function feedSequenceSelectAndLoadVariantTypeList(sequences)
{
 	$('<input type="button" id="resetZoom" value="Reset zoom" style="display:none; float:right; margin-top:3px;" onclick="loadAndDisplayChart();"><div id="densityLoadProgress" style="position:absolute; margin:-3px; right:120px;">&nbsp;</div><form><div style="padding:2px; width:100%; background-color:#f0f0f0;"> Choose a sequence: <select id="chartSequenceList" style="margin-right:20px;" onchange="loadAndDisplayChart();"></select> Choose a variant type: <select id="chartVariantTypeList" onchange="if (options.length > 2) loadAndDisplayChart();"><option value="">ANY</option></select></div></form>').insertBefore('div#chartContainer');
 	for (var key in sequences)
 		$("#chartSequenceList").append("<option value='" + sequences[key] + "'>" + sequences[key] + "</option>");
	
 	$.getJSON('<c:url value="<%=AbstractVariantController.variantTypesListURL%>" />', { module:'${param.module}',project:'${param.project}' }, function(variantTypeJsonResult){				
		for (var key in variantTypeJsonResult)
			$("#chartVariantTypeList").append("<option value='" + variantTypeJsonResult[key] + "'>" + variantTypeJsonResult[key] + "</option>");
		loadAndDisplayChart();
	}).error(function(xhr, ajaxOptions, thrownError) {
		alert(thrownError);
	});

}

function abortOngoingOperation()
{
	if (currentDensityProcessID != null)
		$.ajax({	// abort previously launched request
			url:"<c:url value='<%= AbstractVariantController.processAbortURL %>' />",
			async:false,
			data:{ processID:encodeURIComponent(currentDensityProcessID) },
			success:function(jsonResult){
				if (jsonResult == true)
				{
// 					alert('Aborted ' + currentDensityProcessID);	
				}
				else
					alert("Unable to abort!");
			},
			error:function(xhr, ajaxOptions, thrownError) {
				alert(thrownError);
	    	}
		});
}

window.onbeforeunload = function (e) {
	abortOngoingOperation();
}

function loadAndDisplayChart(minPos, maxPos) {
	var zoomApplied = minPos != null && maxPos != null;
 	$("input#resetZoom").toggle(zoomApplied);
	if (chart != null)
	{
		if (zoomApplied)
			chart.showLoading("Zooming in...");
		else
			chart.destroy();
	}

	var displayedSequence = $("select#chartSequenceList").val();
	var displayedVariantType = $("select#chartVariantTypeList").val();
		
	if (currentDensityProcessID != null)
		abortOngoingOperation();

	currentDensityProcessID = decodeURIComponent('density_' + displayedSequence + '_' + displayedVariantType + '_${param.processID}');

	var densityParameters = {module:'${param.module}',project:'${param.project}',keepExportOnServer:'${param.keepExportOnServer}',variantTypes:'${param.variantTypes}',sequences:'${param.sequences}',gtPattern:'${param.gtPattern}',genotypeQualityThreshold:'${param.genotypeQualityThreshold}',readDepthThreshold:'${param.readDepthThreshold}',missingData:'${param.missingData}',minmaf:'${param.minmaf}',maxmaf:'${param.maxmaf}',minposition:'${param.minposition}',maxposition:'${param.maxposition}',alleleCount:'${param.alleleCount}',geneName:encodeURIComponent('${param.geneName}'.trim().replace(new RegExp(' , ', 'g'), ',')),variantEffects:'${param.variantEffects}',individuals:'${param.individuals}',processID:currentDensityProcessID,displayedSequence:displayedSequence,displayedRangeIntervalCount:displayedRangeIntervalCount,displayedRangeMin:'',displayedRangeMax:''};
	if (displayedVariantType != "")
		densityParameters['displayedVariantType'] = displayedVariantType;
	if (minPos != null)
		densityParameters['displayedRangeMin'] = minPos;
	if (maxPos != null)
		densityParameters['displayedRangeMax'] = maxPos;

	$.ajax({
	    type:"POST",
	    url:'<c:url value="<%=AbstractVariantController.selectionDensityDataURL%>" />',
	    traditional:true,
	    data:densityParameters,
	    success:function(jsonResult) {
			if (jsonResult == null)
			{
				currentDensityProcessID = null;	// complete
				return;
			}
			
			var jsonKeys = Object.keys(jsonResult);
			var intervalSize = parseInt(jsonKeys[1]) - parseInt(jsonKeys[0]);
		
			var jsonValues = new Array();
			var totalVariantCount = 0;
			for (var i=0; i<jsonKeys.length; i++)
			{
				jsonValues.push(jsonResult[jsonKeys[i]]);
				totalVariantCount += jsonResult[jsonKeys[i]];
				jsonKeys[i] = parseInt(parseInt(jsonKeys[i]) + intervalSize/2);
			}
				
			chart = Highcharts.chart('chartContainer', {
		        chart: {
		            type: 'line',
		            zoomType: 'x'
		        },
		        title: {
		            text: 'Distribution of ' + totalVariantCount + ' ' + displayedVariantType + ' variants on sequence ' + displayedSequence
		        },
		        subtitle: {
		            text: 'The value provided for a position is actually the number of variants around it in a interval of size ' + intervalSize
		        },
		        xAxis: {
		            categories: jsonKeys,
		            title: {
		                text: 'Positions on selected sequence'
		            },
		            events: {
		            	afterSetExtremes: function (e) {   
		                    var xAxisDataArray = this.chart.series[0].data;
		                    var xMin = e.min == null ? null : xAxisDataArray[parseInt(e.min)].category;
		                    var xMax = e.max == null ? null : xAxisDataArray[parseInt(e.max)].category;
	                    	loadAndDisplayChart(xMin, xMax);
	                    	e.preventDefault();
		                }
		            }
		        },
		        yAxis: {
		            title: {
		                text: 'Number of variants in interval'
		            }
		        },
		        tooltip: {
		            shared: true,
		            crosshairs: true
		        },
		        plotOptions: {
		            line: {
		                dataLabels: {
		                    enabled: false
		                },
		                marker: {
		                    enabled: false
		                },
		                enableMouseTracking: true
		            }
		        },
		        series: [{
		            name: 'Variants in interval',
		            data: jsonValues
		        }]
		    });
			currentDensityProcessID = null;	// complete
	    },
	    error:function(xhr, ajaxOptions, thrownError) {
	    	alert(thrownError);
	    }
	});
	setTimeout("checkDensityLoadingProgress(\"" + currentDensityProcessID + "\");", minimumProcessQueryIntervalUnit);
}

function checkDensityLoadingProgress(processID)
{
	$.getJSON('<c:url value="<%= AbstractVariantController.progressIndicatorURL %>" />', { module:'${param.module}',processID:processID }, function(jsonResult){
		if (jsonResult != null)
		{
			if (jsonResult['error'] != null)
			{
				parent.totalRecordCount = 0;
				alert("Error occured:\n\n" + jsonResult['error']);
				$('#density').modal('hide');
			}
			else
			{
				$('div#densityLoadProgress').html("<h3>" + jsonResult['progressDescription'] + "</h3>");
				setTimeout("checkDensityLoadingProgress(\"" + processID + "\");", minimumProcessQueryIntervalUnit);
			}
		}
		else
			$("div#densityLoadProgress").html("");
	}).error(function(xhr, ajaxOptions, thrownError) {
		alert(thrownError);
	});
}
</script>

</body>
</html>