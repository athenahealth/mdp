define('appointment', [], function(){
  return {
    initialize: function() {
      var self = this;

      var find_buttons = $('.appointment-by-provider');

      $.get('/templates/appointment', function(template, textStatus, jqXhr){
        self.template = template;
      });

      find_buttons.each(function(index, btn){
        $(btn).on('click', function(event){
          self.find({
            providerid: $(btn).data().providerid
          });
        });
      });
    },
    find: function(args) {
      var self = this;

      $.get("appointment.json", { providerid: args.providerid },
        function(result) {
          var rendered_model = Mustache.render(self.template, result.model);

          $('.appointment-results').html(rendered_model);
      });
    }
  };
});