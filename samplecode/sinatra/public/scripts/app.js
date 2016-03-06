define('app', ['appointment'], function(Appointment) {
  
  return {
    initialize: function() {
      Appointment.initialize();
    }
  };
});