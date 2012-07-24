key = lambda{|n| n==1 ? :one : (n>=2 && n<=4) ? :few : :other}
{:cs => 
  {:i18n => 
    {:keys => [:one, :few, :other], :plural => {:rule => key}}
  }
}
