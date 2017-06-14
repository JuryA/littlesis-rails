/**
 Editable bulk add relationships table 
 Helpful Inspiration: https://codepen.io/ashblue/pen/mCtuA
*/
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('jQuery'), require('../common/utility'));
  } else {
    root.bulkAdd = factory(root.jQuery, root.utility);
  }
}(this, function ($, utility) {
  // This is the structure of table. The number and types of columns vary by
  // relationship type. See utility.js for more information
  // -> [[]]
  function relationshipDetails() {
    var category = Number($('#relationship-cat-select option:selected').val());
    var entityColumns = [ [ 'Name', 'name', 'text'], ['Blurb', 'blurb', 'text'], ['Entity type', 'primary_ext', 'select'] ];
    return entityColumns.concat(utility.relationshipDetails(category));
  }

  // -> [ {} ]
  // same information as above represented as an object.
  function relationshipDetailsAsObject() {
    return relationshipDetails().map(function(x) {
      return {
	display: x[0],
	key: x[1],
	type: x[2]
      };
    });
  }

  // Adds <th> with title to table header
  // [] -> 
  function addColToThead(col) {
   $('#table thead tr').append(
      $('<th>', {
	text: col[0], 
	data: { 'colName': col[1], 'colType': col[2] }
      })
    );
  }

  // => <Span>
  function addRowIcon() {
    return $('<span>', {class: 'table-add', title: 'add a new row to the table'})
      .append( $('<span>', {class: 'glyphicon glyphicon-plus'}) )
      .append( $('<span>', {text: 'Add a row'}));
  }

  // => <Button>
  // Returns button that, when clicked, saves a csv file with the correct headers
  // for the choosen relationship type
  function sampleCSVLink() {
    return $('<button>', {
      text: 'download sample csv',
      class: 'btn btn-default pull-right',
      click: function() {
	var headers = relationshipDetails().map(function(x) { 
	  return x[1];
	}).join(',');
	var blob = new Blob([headers], {type: "text/plain;charset=utf-8"});
	var fileName = utility.relationshipCategories[Number($('#relationship-cat-select option:selected').val())] + '.csv';
	saveAs(blob, fileName);
      }
    });
  }

  // -> <Caption>
  function tableCaption(){
    return $('<caption>')
      .append(addRowIcon())
      .append( $('<input>', {id: 'csv-file'}).attr('type', 'file'))
      .append( sampleCSVLink() );
  }
  
  // Creates Empty table based on the selected category
  function createTable() {
    $('#table table')
      .empty()
      .append(tableCaption())
      .append('<thead><tr></tr></thead><tbody></tbody>');
    
    relationshipDetails().forEach(addColToThead);
    $('#table thead tr').append('<th>Delete</th>');
    
    newBlankRow(); // initialize table with a new blank row
    readCSVFileListener('csv-file'); // handle file uploads to #csv-file
  }
  
  // AJAX request route: /search/entity
  // str, function -> callback([{}])
  function searchRequest(text, callback) {
    $.getJSON('/search/entity', {
      num: 10,
      q: text,
      no_summary: true
    })
     .done(function(result){
       callback(result.map(function(entity){
	 // set the value field to be the name for jquery autocomplete
	 return Object.assign({value: entity.name }, entity);
       }));
     })
     .fail(function() {
       callback([]);
     });
  }

  // options for the entity search autocomplete <td>
  var autocomplete = {
    contenteditable: 'true',
    autocomplete: {
      source: function(request, responce) {
	searchRequest(request.term, responce);
      },
      select: function( event, ui ) {
	event.preventDefault();
	var cell = $(this);
	//  requires order of table to be: name -> blurb -> entityType
	var blurb = cell.next();
	var entityType = blurb.next();
	// add link to cell
	cell.html( $('<a>', { href: 'https://littlesis.org' + ui.item.url, text: ui.item.name, target: '_blank' })) ;
	cell.attr('contenteditable', 'false');
	// store entity id in dataset
	cell.data('entityid', ui.item.id);
	// add reset-field option
	cell.append( 
	  $('<span>', { 
	    'class': 'glyphicon glyphicon-remove reset-name',
	    click: function() {
	      cell.empty();  // empty the cell
	      blurb.empty(); // empty blurb 
	      cell.attr('contenteditable', 'true'); // make cell editable again
	      cell.data('entityid', null); // remove the entity id 
	    }
	  })
	);
	
	blurb.text(ui.item.description ? ui.item.description : '');
	entityType.find('select').selectpicker('val', ui.item.primary_type);
      }
    }
  };

  function primaryExtRadioButtons() {
    // Using selectpicker with multiple and max-options 1 in order to get the
    // 'Nothing selected' message displayed.
    return $('<select>', { 
      'class': 'selectpicker',
      'data-width': 'fit'
    }).append('<option></option><option>Org</option><option>Person</option>');
  }

  // generates <td> for new row
  // [] -> Element
  function td(col) {
    if (col[2] === 'boolean') {  // boolean column
      return $('<td>').append('<input type="checkbox">');  // include checkbox
    } else if (col[1] === 'name') { // autocomplete for entity
      return $('<td>', autocomplete);
    } else if (col[1] === 'primary_ext') {
      return $('<td>').append(primaryExtRadioButtons());
    } 
    else {
      return $('<td>', { contenteditable: 'true'}); // return editable column
    }
  }
  
  // Adds a new blank row to the table
  // Returns the newly created row
  function newBlankRow() {
    var removeTd = $('<td>').append('<span class="table-remove glyphicon glyphicon-remove"></span>');
    var row = $('<tr>').append(relationshipDetails().map(td).concat(removeTd));
    $('#table tbody').append(row);
    // Because we create the selectpicker after the dom has loaded, we must iniitalize it here:
    $('#table .selectpicker').selectpicker();
    return row;
  }

  // This returns the cell data
  // Most types simply need to return the text inside the element.
  // Two expetions: checkboxes and <select>'s
  function extractCellData(cell, rowInfo) {
    if (rowInfo.type === 'boolean') {
      // Technically we should allow three values for this field: true, false, and null.
      // However, to keep things simple, right now the false/un-checked state defaults to null
      // So in this tool there is no way of saying that a person is NOT a board member.
      return cell.find('input').is(':checked') ? true : null; 
    } else if (rowInfo.type === 'select') {
      var selectpickerArr = cell.find('.selectpicker').selectpicker('val');
      return selectpickerArr ? selectpickerArr : null;
    } else if (rowInfo.key === 'name' && Boolean(cell.data('entityid'))) {
      // If the entity was selected using the search there will be an entityid field in the cell's dataset
      return cell.data('entityid');
    } else {
      return (cell.text() === '') ? null : cell.text();
    }
  }

  var YES_VALUES = [ 1, '1', 'yes', 'Yes', 'YES', 'y', 'Y', true, 'true', 't', 'T', 'True', 'TRUE'];
  var ORG_VALUES = [ 'org', 'Org', 'ORG', 'organization', 'Organization', 'ORGANIZATION', 'o', 'O' ];
  var PERSON_VALUES = [ 'person', 'Person', 'PERSON', 'p', 'P', 'per', 'PER', 'capitalist pig'];

  // This updates the cell with the provided value
  // Similar to extractCellData, but it sets
  // the values of the cells instead of extracting them
  // input: <Td>, {relationshipDetailsAsObject}, any
  function updateCellData(cell, rowInfo, value) {
    if (rowInfo.type === 'boolean') {
      
      if (YES_VALUES.includes(value)) {
	cell.find('input').prop('checked', true);
      }
      
    } else if (rowInfo.type === 'select') {
      
      if (rowInfo.key === 'primary_ext') {
	if (ORG_VALUES.includes(value)) {
	  cell.find('.selectpicker').selectpicker('val', 'Org');
	} else if (PERSON_VALUES.includes(value)) {
	  cell.find('.selectpicker').selectpicker('val', 'Person');
	}
      } 
      
    } else if (rowInfo.key === 'name') {
      // You can provide the id of a littlesis entity as a name
      if (Number.isInteger(Number(value))) {
	cell.data('entityid', Number(value));
      }

      cell.text(value);

    } else {
      cell.text(value);
    }
  };


  //  [{}], element -> {}
  function rowToJson(tableDetails, row) {
    var obj = {};
    tableDetails.forEach(function(rowInfo,i) {
      var cell = $(row).find('td:nth-child(' + (i + 1) + ')');
      obj[rowInfo.key] = extractCellData(cell, rowInfo);
    });
    return obj;
  }

  // str, [ {} ] -> [ {} ]
  // columns should be relationshipDetailsAsObject()
  // Given the selector of a <table> and it's associated column data
  // it returns the data as an array of objects
  function tableToJson(selector, columns) {
    var _rowToJson = rowToJson.bind(null, columns);
    return $(selector + ' tbody tr').map(function(){
      return _rowToJson(this);
    }).toArray();
  }

  // <td> Element -> false
  // displays validations and return false;
  function invalidDisplay(element) {
    $(element).addClass('bg-warning');
    return false;
  }

  // input: arr, element, function
  // calls the provided function on each cell in the row with these args:
  // rowInfo ({}), cell (element), cellData (various)
  function traverseRow(columns, row, func) {
    columns.forEach(function(rowInfo, i){
      var cell = $(row).find('td:nth-child(' + (i + 1) + ')');
      var cellData = extractCellData(cell, rowInfo.type);
      func(rowInfo, cell, cellData);
    });
  }

  // Calls invalidDisplay  for invalid cells and returns false;
  // Otherwise it returns true
  // {}, element, * -> boolean
  function cellValidation(rowInfo, cell, cellData) {
    if (['name', 'primary_ext'].includes(rowInfo.key) && !cellData) {
      console.log(rowInfo.key + ' is blank');
      return invalidDisplay(cell);
    }
    if (cellData && rowInfo.type === 'date' && !utility.validDate(cellData)) {
      console.log(cellData + ' is an invalid date');
      return invalidDisplay(cell);
    }
    return true;
  }
  
  // an indicator that can only go from true to false.
  function ValidFlag() {
    this.status = true;
    this.setStatus = function(input) {
      if (!input) { this.status = false; }
    };
  }

  // Verifies that each cell is valid
  // str -> boolean
  function validate(selector) {
    var validFlag = new ValidFlag();
    var columns = relationshipDetailsAsObject();
    // for each row
    $(selector + ' tbody tr').each(function(){
      // for each cell in the row
      traverseRow(columns, this, function(rowInfo, cell, cellData){
	// highlighed cell if invalid and return status
	validFlag.setStatus(cellValidation(rowInfo, cell, cellData));
      });
    });
    return validFlag.status;
  }

  function showAlert(message, alertType) {
    var html = '<div class="alert alert-dismissible !!TYPE!!" role="alert"><button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>!!MESSAGE!!</div>'
      .replace('!!MESSAGE!!', message).replace('!!TYPE!!', alertType);
    $('#alert-container').html(html);
  }

  function validateReference() {
    $('#alert-container').empty();
    var url = document.getElementById('reference-url');
    if (url.validity.valid) {
      return true;
    } else {
      showAlert('Please enter in a valid source url', 'alert-danger');
      return false;
    }
  }

  function submit() {
    if (validateReference()) {
      $('.bg-warning').removeClass('bg-warning');
      if ( validate('#table') ) {
	console.log(tableToJson('#table', relationshipDetailsAsObject()));
	submitRequest();
      } else {
	showAlert('Some cells are missing information or invalid!');
      }
    }
  }

  // data format:
  // {
  //   entity1_id: int,
  //   category_id: int,
  //   reference: {
  //     source: str
  //     name: str
  //   }
  //   relationships: [{}]
  // }
  function prepareTableData(data) {
    var entity1_id = utility.entityInfo('entityid');
    var category_id = Number($('#relationship-cat-select option:selected').val());
    var reference = {
      'source': $('#reference-url').val(),
      'name': $('#reference-name').val()
    };
    return {
      entity1_id: entity1_id,
      category_id: category_id,
      reference: reference,
      relationships: data
    };
  }

  var afterRequest = {
    success: function() {
      $('#table table').empty();
      showAlert('The request was successful!', 'alert-success');
    },
    error: function() {
      alert('something went wrong :(');
    }
  };
  

  // Sends the data for submission
  // [{}] -> callbacks
  function submitRequest() {
    var data = prepareTableData(tableToJson('#table', relationshipDetailsAsObject()));
    console.log(data);
    $.ajax({
      method: 'POST',
      url: '/relationships/bulk_add',
      data: data,
      statusCode: {
	201: function() {
	  afterRequest.success();
	},
	207: function() {
	  // partial sucuess...should eventually figure out what to do here
	  afterRequest.success();
	},
	400: function() {
	  afterRequest.error();
	},
	422: function() { 
	  afterRequest.error();
	}
      },
      error: function() {
	afterRequest.error();
      }
    });
  }

  // Takes CSV string and writes result to table
  // see github.com/mholt/PapaParse for PapeParse library docs
  function csvToTable(csvStr) {
    // csv.data contains an array of objects where the keys are the same as rowInfo.key
    var csv = Papa.parse(csvStr, { header: true, skipEmptyLines: true});
    var columns = relationshipDetailsAsObject();
    
    csv.data.forEach(function(rowData) {
      var newRow = newBlankRow();
      traverseRow(columns, newRow, function(rowInfo, cell) {
	updateCellData(cell, rowInfo, rowData[rowInfo.key]);
      });
    });
  }

  // input: str (element id of <input type="file">)
  // attaches a callback to provided element
  // which calls csvToTable with the contents of the file
  // after a file has been selected
  function readCSVFileListener(fileInputId) {
    if (!utility.fileOpeningAbilities()) { return; }

    function handleFileSelect() {
      if (this.files.length > 0) {  // do nothing if no file is selected
	var reader = new FileReader();
	reader.onloadend = function() {  // triggered when file is finished being read
	  if (reader.result) { 
	    csvToTable(reader.result);
	  } else {
	    console.error('Error reading the csv file or the file is empty');
	  }
	};
	reader.readAsText(this.files[0]);
      }
    }
    
    document.getElementById(fileInputId).addEventListener('change', handleFileSelect, false);
  }


  // Establishes listeners for:
  //   - click to add a new row
  //   - remove row
  //   - select a relationship category
  //   - upload data button click
  function domListeners() {
    $('#table').on('click', '.table-add', function() { newBlankRow(); });
    $('#table').on('click', '.table-remove', function() {
      $(this).parents('tr').detach();
    });
    $('#relationship-cat-select').change(function(x){
      createTable();
      $('#upload-btn').removeClass('hidden');
    });
    $('#upload-btn').click(function() {
      submit();
      
    });
  } 

  return {
    relationshipDetails: relationshipDetails,
    relationshipDetailsAsObject: relationshipDetailsAsObject,
    createTable: createTable,
    tableToJson: tableToJson,
    search: searchRequest,
    newBlankRow: newBlankRow,
    validate: validate,
    cellValidation: cellValidation,
    invalidDisplay: invalidDisplay,
    init: function() { 
      domListeners();
    }
  };
  
}));
