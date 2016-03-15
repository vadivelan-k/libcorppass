# Setup Session Serialization

class Warden::SessionSerializer
  def serialize(user)
    [user.class.name, user.serialize]
  end

  def deserialize(serialized)
    klass, serialized_data = serialized
    klass.constantize.deserialize serialized_data
  end
end
