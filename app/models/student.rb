class Student < ApplicationRecord
    enum track: { residential: 0, executive: 1 }
end
